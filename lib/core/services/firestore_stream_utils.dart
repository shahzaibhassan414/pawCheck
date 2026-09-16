import 'package:cloud_firestore/cloud_firestore.dart';

/// For `Stream.handleError` on a live Firestore `.snapshots()` listener.
///
/// Signing out clears the Firebase Auth session immediately
/// (`SettingsScreen._confirmSignOut` awaits `signOut()` before navigating
/// away), but the screen holding this listener doesn't get disposed until
/// the navigation after it completes — so for a brief window, a still-live
/// listener gets re-evaluated against the security rules with no `auth`
/// token and is rejected. Without this, that `permission-denied` propagates
/// as an unhandled exception and crashes the app instead of just going
/// quiet on a screen that's about to be torn down anyway. Any other error
/// still propagates normally.
void ignorePermissionDeniedDuringSignOut(Object error) {
  if (error is! FirebaseException || error.code != 'permission-denied') {
    throw error;
  }
}
