import 'dart:convert';

import 'package:flutter/widgets.dart';

/// Resolves a [Scan.photoUrl] to a renderable [ImageProvider]. Scan photos
/// are currently stored as `data:image/jpeg;base64,...` URIs directly in
/// Firestore (no Firebase Storage — see the persistence-layer plan for why),
/// so this decodes those into a [MemoryImage]. Anything else falls back to
/// [NetworkImage], keeping a real hosted-URL path open for a future Storage
/// migration without another rewrite of every call site.
ImageProvider photoImageProvider(String url) {
  if (url.startsWith('data:')) {
    final base64Part = url.substring(url.indexOf(',') + 1);
    return MemoryImage(base64Decode(base64Part));
  }
  return NetworkImage(url);
}
