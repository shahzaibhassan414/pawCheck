import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/env.dart';
import 'ai_guardrail.dart';
import 'ai_triage_service.dart';

/// System prompt sent with every request, verbatim from PRD Section 7 —
/// this is a safety requirement, not a style choice. Do not edit without
/// updating the PRD. Species/note context is supplied per-request in the
/// user turn (see [GeminiAiTriageService.analyze]), since this instruction
/// is fixed across every call.
const String _systemPrompt =
    "You are a triage assistant helping a pet owner understand what "
    "they're seeing — you are not a veterinarian and must never provide a "
    "definitive diagnosis, treatment, or medication guidance. Given this "
    "photo of a [species] and this optional note, return: (1) a "
    "plain-language description of what is visible, (2) 2-4 plausible "
    "non-diagnostic explanations, (3) an urgency rating of exactly one of: "
    "Low, Monitor, See a vet soon, Emergency. Always err toward a higher "
    "urgency rating when uncertain. Always recommend a vet visit for "
    "Monitor and above.\n\n"
    "Reject or flag images that do not contain a dog or cat by returning "
    'urgency "Monitor" with a description asking the user to retake the '
    'photo. If the photo is inconclusive, also default to "Monitor" with '
    "a note to retake or watch for changes.\n\n"
    'Never output medication names, dosages, or "give them X" language.\n\n'
    "Respond with only JSON matching this shape: "
    '{"description": string, "causes": string[2..4], '
    '"urgency": "Low" | "Monitor" | "See a vet soon" | "Emergency", '
    '"vet_recommended": boolean}';

/// Live Gemini-backed [AiTriageService]. Never used in automated tests —
/// see `MockAiTriageService` for that (PRD Section 12).
class GeminiAiTriageService implements AiTriageService {
  GeminiAiTriageService({String? apiKey, String modelName = 'gemini-2.5-flash'})
    : _model = GenerativeModel(
        model: modelName,
        apiKey: apiKey ?? Env.geminiApiKey,
        systemInstruction: Content.system(_systemPrompt),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

  final GenerativeModel _model;

  @override
  Future<TriageResult> analyze({
    required Uint8List imageBytes,
    required String species,
    String? note,
  }) async {
    final promptText = StringBuffer('Species: $species.');
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      promptText.write(' Owner note: $trimmedNote');
    }

    final GenerateContentResponse response;
    try {
      response = await _model.generateContent([
        Content.multi([
          TextPart(promptText.toString()),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);
    } catch (e) {
      throw AiTriageException('Gemini request failed', cause: e);
    }

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const AiTriageException('Gemini returned an empty response');
    }
    return parseResponse(text);
  }

  /// Parses and guardrails a raw Gemini response body. A static,
  /// network-free entry point so Milestone 2's unit tests can exercise the
  /// parsing/guardrail pipeline with canned payloads without ever hitting
  /// the live API (PRD Section 12 — never call live Gemini in automated
  /// tests).
  static TriageResult parseResponse(String rawText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_stripCodeFence(rawText));
    } on FormatException catch (e) {
      throw AiTriageException('Gemini response was not valid JSON', cause: e);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AiTriageException('Gemini response JSON was not an object');
    }
    final result = TriageResult.fromJson(decoded);
    return AiGuardrail.sanitize(result);
  }

  /// Gemini occasionally wraps JSON in a markdown code fence even when
  /// `responseMimeType: application/json` is requested — strip it before
  /// decoding rather than letting `jsonDecode` fail on it.
  static String _stripCodeFence(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('```')) return trimmed;
    final withoutOpenFence = trimmed.replaceFirst(
      RegExp(r'^```[a-zA-Z]*\n?'),
      '',
    );
    return withoutOpenFence.replaceFirst(RegExp(r'\n?```$'), '');
  }
}
