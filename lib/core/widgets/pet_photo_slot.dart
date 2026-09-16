import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/photo_image_provider.dart';

/// "Pet photo — circular user-uploadable photo slot, placeholder
/// 'Add photo'" per the "Paw Check claude design" doc's section 3 — shared
/// between the full account setup screen and Home's add-pet dialog
/// (section 4's simpler "photo optional, name + species cards only" form).
class PetPhotoSlot extends StatelessWidget {
  const PetPhotoSlot({
    super.key,
    required this.photo,
    required this.onTap,
    this.existingPhotoUrl,
    this.size = 96,
  });

  /// A freshly picked photo, not yet saved — takes priority over
  /// [existingPhotoUrl] once set, so picking a new photo in edit mode
  /// previews it immediately instead of still showing the old one.
  final File? photo;
  final VoidCallback onTap;

  /// The pet's already-persisted [Pet.photoUrl], shown until [photo] picks
  /// a replacement — lets edit mode pre-fill the slot instead of always
  /// starting empty.
  final String? existingPhotoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final image = photo != null
        ? FileImage(photo!)
        : existingPhotoUrl != null
        ? photoImageProvider(existingPhotoUrl!)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outlineVariant, width: 2),
          image: image != null
              ? DecorationImage(image: image, fit: BoxFit.cover)
              : null,
        ),
        child: image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add photo',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
