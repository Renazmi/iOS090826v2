import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Keep encoded photos well under the Firestore 1 MiB document limit.
const maxProfilePhotoBytes = 350 * 1024;

/// Picks an image from the gallery and returns a data URL (matches web storage format).
Future<String?> pickProfilePhotoDataUrl() async {
  return pickRegistrationFacePhotoDataUrl(fromCamera: false);
}

/// Selfie (front camera) or gallery upload for registration identity photo.
Future<String?> pickRegistrationFacePhotoDataUrl({required bool fromCamera}) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 480,
    maxHeight: 480,
    imageQuality: 70,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (bytes.length > maxProfilePhotoBytes) {
    throw ProfilePhotoException(
      'Photo is too large to sync to TrackIT admin. Choose a clearer, smaller photo.',
    );
  }

  final mime = _mimeFromName(file.name.isNotEmpty ? file.name : file.path);
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

bool isValidProfilePhotoDataUrl(String value) {
  return value.trim().startsWith('data:image/');
}

String _mimeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

class ProfilePhotoException implements Exception {
  ProfilePhotoException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Avatar widget for profile cards — supports data URLs, assets, or letter fallback.
class TrackitProfileAvatar extends StatelessWidget {
  const TrackitProfileAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackLetter,
    this.size = 56,
  });

  final String? imageUrl;
  final String fallbackLetter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl?.trim();
    Widget? imageChild;

    if (trimmed != null && trimmed.isNotEmpty) {
      if (trimmed.startsWith('data:image/')) {
        try {
          final base64Part = trimmed.split(',').last;
          final bytes = base64Decode(base64Part);
          imageChild = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _letterFallback(size, fallbackLetter),
          );
        } catch (_) {
          imageChild = null;
        }
      } else if (trimmed.startsWith('assets/')) {
        imageChild = Image.asset(
          trimmed,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _letterFallback(size, fallbackLetter),
        );
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: imageChild == null ? _avatarGradient : null,
        color: imageChild != null ? Colors.black12 : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC62828).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageChild ??
          _letterFallback(size, fallbackLetter),
    );
  }

  static Widget _letterFallback(double size, String fallbackLetter) {
    return Center(
      child: Text(
        fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.39,
        ),
      ),
    );
  }

  static const _avatarGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFFC62828)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
