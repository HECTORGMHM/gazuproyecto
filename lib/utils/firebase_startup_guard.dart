import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseStartupIssue implements Exception {
  const FirebaseStartupIssue(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebaseStartupGuard {
  static const _placeholderPrefix = 'YOUR_';
  static const _exampleBundleId = 'com.example.gazu';

  static void validateCurrentPlatform() {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      final invalidFields = <String>[
        if (_isPlaceholder(options.apiKey)) 'apiKey',
        if (_isPlaceholder(options.appId)) 'appId',
        if (_isPlaceholder(options.messagingSenderId)) 'messagingSenderId',
        if (_isPlaceholder(options.projectId)) 'projectId',
        if (_isPlaceholder(options.iosClientId)) 'iosClientId',
        if (_isPlaceholder(options.iosBundleId)) 'iosBundleId',
      ];

      if (invalidFields.isNotEmpty) {
        throw FirebaseStartupIssue(
          'Firebase no está configurado para ${_platformName()}.\n'
          'Campos pendientes: ${invalidFields.join(', ')}.\n'
          'Ejecuta `flutterfire configure` y agrega los archivos nativos faltantes.',
        );
      }
    } on UnsupportedError catch (error) {
      throw FirebaseStartupIssue(error.message ?? 'Plataforma no soportada.');
    }
  }

  static bool _isPlaceholder(String? value) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }

    final normalized = value.trim().toUpperCase();
    return normalized.startsWith(_placeholderPrefix) ||
        value.trim() == _exampleBundleId;
  }

  static String _platformName() {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }
}
