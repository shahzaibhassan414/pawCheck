import { SignJWT, importPKCS8 } from "jose";

import { OTP_EMAIL_LOGO_BASE64 } from "./email-assets";

export interface Env {
  OTP_KV: KVNamespace;
  BREVO_API_KEY: string;
  BREVO_SENDER_EMAIL: string;
  FIREBASE_PROJECT_ID: string;
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;
}

// Hardcoded rather than derived from the incoming request — this is used
// from `otpEmailHtml`, which only has `code` to work with, not a Request.
// Update this if the Worker is ever moved to a custom domain.
const WORKER_BASE_URL = "https://pawcheck-otp.shahzaibhassan414.workers.dev";

const OTP_TTL_SECONDS = 10 * 60; // 10 minutes
const SEND_COOLDOWN_MS = 60 * 1000; // 1 minute between sends to the same email
const MAX_ATTEMPTS = 5;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

interface OtpRecord {
  code: string;
  expiresAt: number;
  attempts: number;
  lastSentAt: number;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function normalizeEmail(raw: unknown): string | null {
  const email = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  return email && EMAIL_PATTERN.test(email) ? email : null;
}

function generateCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Table layout + inline styles throughout — the only markup/CSS approach
 * that renders consistently across email clients (notably Outlook desktop,
 * which uses Word's rendering engine and ignores most non-inline CSS and
 * modern layout). Colors match the app's own theme
 * (`lib/core/theme/app_theme.dart`'s violet seed `0xFF7C3AED` and cream
 * scaffold `0xFFFAFAF7`) so the email reads as the same product.
 */
function otpEmailHtml(code: string): string {
  const digits = code
    .split("")
    .map(
      (digit) =>
        `<td style="width:40px;height:52px;background-color:#FFFFFF;border:1.5px solid #E4DEF2;border-radius:10px;` +
        `text-align:center;vertical-align:middle;color:#7C3AED;font-size:26px;font-weight:700;` +
        `font-family:Menlo,Consolas,monospace;">${digit}</td>`,
    )
    .join(`<td style="width:6px;"></td>`);

  return `<!doctype html>
<html>
  <body style="margin:0;padding:0;background-color:#FAFAF7;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#FAFAF7;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:420px;background-color:#FFFFFF;border-radius:20px;overflow:hidden;box-shadow:0 2px 16px rgba(28,15,74,0.06);">
            <tr>
              <td align="center" style="background-color:#7C3AED;background-image:linear-gradient(135deg,#7C3AED,#6B2FD6);padding:32px 24px;">
                <img src="${WORKER_BASE_URL}/logo.png" width="56" height="56" alt="PawCheck" style="display:block;margin:0 auto;border:0;" />
                <div style="color:#FFFFFF;font-size:21px;font-weight:700;margin-top:12px;letter-spacing:0.2px;">PawCheck</div>
              </td>
            </tr>
            <tr>
              <td style="padding:36px 32px 6px 32px;text-align:center;">
                <div style="color:#1C1B1F;font-size:19px;font-weight:700;margin-bottom:10px;">
                  Your verification code
                </div>
                <div style="color:#5F5A66;font-size:14px;line-height:1.6;">
                  Enter this code to keep your pets' scans backed up and private to your account.
                </div>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:24px 32px 8px 32px;">
                <table role="presentation" cellpadding="0" cellspacing="0"><tr>${digits}</tr></table>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 32px 32px 32px;text-align:center;">
                <div style="color:#8A8591;font-size:13px;line-height:1.6;">
                  This code expires in <strong style="color:#5F5A66;">10 minutes</strong>. If you didn't request it, you can safely ignore this email.
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:20px 32px;border-top:1px solid #EFEBF5;text-align:center;">
                <div style="color:#B5B0BC;font-size:12px;">
                  🐾 A calm second opinion for your pet
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

/**
 * Sends the code via Brevo's transactional email API. `BREVO_SENDER_EMAIL`
 * (wrangler.toml) must be a verified sender in the Brevo dashboard, or
 * Brevo rejects the send. `textContent` stays alongside `htmlContent` for
 * plain-text mail clients and spam-filter scoring (an HTML-only email with
 * no text alternative is itself a mild spam signal).
 */
async function sendCodeEmail(env: Env, email: string, code: string): Promise<void> {
  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": env.BREVO_API_KEY,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      sender: { name: "PawCheck", email: env.BREVO_SENDER_EMAIL },
      to: [{ email }],
      subject: `🐾 ${code} is your PawCheck verification code`,
      textContent: `Your PawCheck verification code is ${code}. It expires in 10 minutes.`,
      htmlContent: otpEmailHtml(code),
    }),
  });
  if (!response.ok) {
    throw new Error(`Brevo send failed: ${response.status} ${await response.text()}`);
  }
}

/**
 * There's no Firebase Admin SDK available in a Worker, so this hand-rolls
 * the two pieces it would normally provide: a Google OAuth2 access token
 * (signed from the service account's own key, exchanged at Google's token
 * endpoint) for calling the Identity Toolkit REST API, and a self-signed
 * Firebase custom token (same claim shape `admin.auth().createCustomToken`
 * produces) for the client to exchange via `signInWithCustomToken`.
 */
async function getPrivateKey(env: Env) {
  let pem = env.FIREBASE_PRIVATE_KEY.trim();
  // Tolerate a value copied with its surrounding JSON quotes still attached.
  if (pem.startsWith('"') && pem.endsWith('"')) {
    pem = pem.slice(1, -1);
  }
  // Normalize both literal "\n" escape sequences (from pasting the JSON
  // field's raw text) and real \r\n line endings to plain \n.
  pem = pem.replace(/\\n/g, "\n").replace(/\r\n?/g, "\n").trim();

  // Tolerate the secret having been set to just the raw base64 body, with
  // the "-----BEGIN/END PRIVATE KEY-----" armor stripped off during copying.
  if (!pem.includes("-----BEGIN")) {
    pem = `-----BEGIN PRIVATE KEY-----\n${pem}\n-----END PRIVATE KEY-----`;
  }

  return importPKCS8(pem, "RS256");
}

async function getGoogleAccessToken(env: Env): Promise<string> {
  const key = await getPrivateKey(env);
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope:
      "https://www.googleapis.com/auth/identitytoolkit https://www.googleapis.com/auth/datastore",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(env.FIREBASE_CLIENT_EMAIL)
    .setSubject(env.FIREBASE_CLIENT_EMAIL)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(
      `Google OAuth2 token exchange failed: ${response.status} ${await response.text()}`,
    );
  }
  const data = (await response.json()) as { access_token: string };
  return data.access_token;
}

/** Finds the Firebase Auth user for `email`, creating one (emailVerified) if none exists. */
async function findOrCreateUid(email: string, accessToken: string, env: Env): Promise<string> {
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    "Content-Type": "application/json",
  };

  const lookupResponse = await fetch(
    "https://identitytoolkit.googleapis.com/v1/accounts:lookup",
    {
      method: "POST",
      headers,
      body: JSON.stringify({ email: [email], targetProjectId: env.FIREBASE_PROJECT_ID }),
    },
  );
  if (!lookupResponse.ok) {
    throw new Error(
      `accounts:lookup failed: ${lookupResponse.status} ${await lookupResponse.text()}`,
    );
  }
  const lookupData = (await lookupResponse.json()) as {
    users?: { localId: string }[];
  };
  if (lookupData.users && lookupData.users.length > 0) {
    return lookupData.users[0].localId;
  }

  const signUpResponse = await fetch(
    "https://identitytoolkit.googleapis.com/v1/accounts:signUp",
    {
      method: "POST",
      headers,
      body: JSON.stringify({
        email,
        emailVerified: true,
        targetProjectId: env.FIREBASE_PROJECT_ID,
      }),
    },
  );
  if (!signUpResponse.ok) {
    throw new Error(
      `accounts:signUp failed: ${signUpResponse.status} ${await signUpResponse.text()}`,
    );
  }
  const signUpData = (await signUpResponse.json()) as { localId: string };
  return signUpData.localId;
}

/** Self-signed Firebase custom token — the client exchanges this via `signInWithCustomToken`. */
async function mintCustomToken(uid: string, env: Env): Promise<string> {
  const key = await getPrivateKey(env);
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({ uid, claims: {} })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(env.FIREBASE_CLIENT_EMAIL)
    .setSubject(env.FIREBASE_CLIENT_EMAIL)
    .setAudience(
      "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit",
    )
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
}

// Same top-level collection the client's FirestorePetRepository/
// FirestoreScanRepository/FirestoreDeviceRepository write to, keyed the
// same way (lowercased email as the document id) — see firestore.rules'
// comment for the full picture of what lives on this document vs. its
// subcollections.
const USERS_COLLECTION = "users";

function firestoreDocUrl(env: Env, email: string): string {
  return (
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}` +
    `/databases/(default)/documents/${USERS_COLLECTION}/${encodeURIComponent(email)}`
  );
}

async function firestoreDocExists(email: string, accessToken: string, env: Env): Promise<boolean> {
  const response = await fetch(firestoreDocUrl(env, email), {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  return response.ok;
}

/**
 * Merges `fields` into the `users/{email}` document (created if it doesn't
 * exist yet) via Firestore's REST API — there's no Admin SDK in a Worker,
 * so this authenticates with the same service-account OAuth2 access token
 * used for the Identity Toolkit calls above (scoped to `datastore` as well
 * as `identitytoolkit`). This bypasses Firestore Security Rules entirely,
 * the same way the Admin SDK would.
 */
async function firestoreMergeFields(
  email: string,
  fields: Record<string, string | boolean | null>,
  accessToken: string,
  env: Env,
): Promise<void> {
  const firestoreFields: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    firestoreFields[key] =
      value === null
        ? { nullValue: null }
        : typeof value === "boolean"
          ? { booleanValue: value }
          : { stringValue: value };
  }
  const updateMask = Object.keys(fields)
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join("&");

  const response = await fetch(`${firestoreDocUrl(env, email)}?${updateMask}`, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields: firestoreFields }),
  });
  if (!response.ok) {
    throw new Error(`Firestore write failed: ${response.status} ${await response.text()}`);
  }
}

/**
 * Records that `email` started sign-in — only on the *first* time it's
 * seen, so a returning user requesting a fresh code never regresses an
 * already-`otpVerified: true` record back to false.
 */
async function recordEmailEntered(email: string, env: Env): Promise<void> {
  const accessToken = await getGoogleAccessToken(env);
  if (await firestoreDocExists(email, accessToken, env)) return;
  await firestoreMergeFields(
    email,
    { email, otpVerified: false, uid: null, createdAt: new Date().toISOString(), verifiedAt: null },
    accessToken,
    env,
  );
}

/**
 * Generates a 6-digit code, stores it (with an expiry and a fresh attempt
 * counter) in `OTP_KV`, and emails it via Brevo. Rejects if the same email
 * requested a code in the last minute — both a basic abuse guard and what
 * makes a "Resend code" button behave sanely.
 */
async function handleSendOtp(request: Request, env: Env): Promise<Response> {
  const body = await request.json().catch(() => null);
  const email = normalizeEmail((body as { email?: unknown } | null)?.email);
  if (!email) return json({ message: "Enter a valid email address." }, 400);

  try {
    await recordEmailEntered(email, env);
  } catch (error) {
    // Tracking-only — never blocks the actual OTP send on a Firestore hiccup.
    console.error("recordEmailEntered failed:", error);
  }

  const existing = await env.OTP_KV.get<OtpRecord>(email, "json");
  if (existing && Date.now() - existing.lastSentAt < SEND_COOLDOWN_MS) {
    return json({ message: "Please wait a moment before requesting another code." }, 429);
  }

  const code = generateCode();
  const record: OtpRecord = {
    code,
    expiresAt: Date.now() + OTP_TTL_SECONDS * 1000,
    attempts: 0,
    lastSentAt: Date.now(),
  };
  await env.OTP_KV.put(email, JSON.stringify(record), { expirationTtl: OTP_TTL_SECONDS });

  try {
    await sendCodeEmail(env, email, code);
  } catch {
    return json({ message: "Couldn't send the verification email." }, 500);
  }

  return json({ sent: true });
}

/**
 * Checks the submitted code against `OTP_KV`, then finds-or-creates a
 * Firebase Auth user for that email and returns a custom token the client
 * exchanges for a real sign-in via `signInWithCustomToken`.
 */
async function handleVerifyOtp(request: Request, env: Env): Promise<Response> {
  const body = await request.json().catch(() => null);
  const email = normalizeEmail((body as { email?: unknown } | null)?.email);
  const rawCode = (body as { code?: unknown } | null)?.code;
  const code = typeof rawCode === "string" ? rawCode.trim() : "";
  if (!email) return json({ message: "Enter a valid email address." }, 400);
  if (!code) return json({ message: "Enter the code from your email." }, 400);

  const record = await env.OTP_KV.get<OtpRecord>(email, "json");
  if (!record) {
    return json({ message: "Request a new code — none is pending for this email." }, 404);
  }
  if (Date.now() > record.expiresAt) {
    await env.OTP_KV.delete(email);
    return json({ message: "That code has expired. Request a new one." }, 410);
  }
  if (record.attempts >= MAX_ATTEMPTS) {
    await env.OTP_KV.delete(email);
    return json({ message: "Too many incorrect attempts. Request a new code." }, 429);
  }
  if (record.code !== code) {
    record.attempts += 1;
    // Workers KV requires a minimum 60s TTL, even this close to the code's
    // own logical expiry (checked separately above on every read) — this
    // TTL is just eventual cleanup, not the source of truth for expiry.
    const remainingSeconds = Math.max(60, Math.ceil((record.expiresAt - Date.now()) / 1000));
    await env.OTP_KV.put(email, JSON.stringify(record), { expirationTtl: remainingSeconds });
    return json({ message: "That code is incorrect." }, 403);
  }

  await env.OTP_KV.delete(email);

  let token: string;
  let accessToken: string;
  let uid: string;
  try {
    accessToken = await getGoogleAccessToken(env);
    uid = await findOrCreateUid(email, accessToken, env);
    token = await mintCustomToken(uid, env);
  } catch (error) {
    console.error("sign-in failed:", error);
    return json({ message: "Something went wrong signing you in. Try again." }, 500);
  }

  try {
    await firestoreMergeFields(
      email,
      { otpVerified: true, uid, verifiedAt: new Date().toISOString() },
      accessToken,
      env,
    );
  } catch (error) {
    // Tracking-only — the user is already validly signed in at this point.
    console.error("recordEmailVerified failed:", error);
  }

  return json({ token });
}

/**
 * Serves the email template's logo as a real hosted image. Gmail (unlike
 * most other clients) unreliably renders base64 `data:` URIs embedded
 * directly in HTML email — confirmed by testing (the logo silently didn't
 * load there) — so it needs an actual `https://` URL to fetch, same as any
 * other web image. `immutable` is safe here: this endpoint's bytes only
 * change on a redeploy that edits `email-assets.ts`, at which point this is
 * a new Worker version anyway.
 */
function handleLogo(): Response {
  const bytes = Uint8Array.from(atob(OTP_EMAIL_LOGO_BASE64), (c) => c.charCodeAt(0));
  return new Response(bytes, {
    headers: {
      "Content-Type": "image/png",
      "Cache-Control": "public, max-age=31536000, immutable",
    },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const pathname = new URL(request.url).pathname;
    if (request.method === "GET" && pathname === "/logo.png") {
      return handleLogo();
    }
    if (request.method !== "POST") {
      return json({ message: "Method not allowed." }, 405);
    }

    switch (pathname) {
      case "/send-otp":
        return handleSendOtp(request, env);
      case "/verify-otp":
        return handleVerifyOtp(request, env);
      default:
        return json({ message: "Not found." }, 404);
    }
  },
};
