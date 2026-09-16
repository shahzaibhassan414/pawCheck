import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/utils/photo_image_provider.dart';

void main() {
  test('a data: URI decodes to a MemoryImage with the original bytes', () {
    final bytes = utf8.encode('not a real image, just test bytes');
    final url = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    final provider = photoImageProvider(url);

    expect(provider, isA<MemoryImage>());
    expect((provider as MemoryImage).bytes, bytes);
  });

  test('an https URL resolves to a NetworkImage', () {
    const url = 'https://example.com/photo.jpg';

    final provider = photoImageProvider(url);

    expect(provider, isA<NetworkImage>());
    expect((provider as NetworkImage).url, url);
  });
}
