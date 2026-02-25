import 'package:flutter/foundation.dart';
import 'config_stub.dart' if (dart.library.io) 'config_io.dart' as impl;

/// Central API configuration. Use for dev/staging/prod or platform-specific URLs.
class AppConfig {
  AppConfig._();

  /// Base URL for the Echonova API.
  /// - Android Emulator: 10.0.2.2 points to host's localhost.
  /// - Other (Windows, iOS, Web): localhost.
  static String get apiBaseUrl => impl.getApiBaseUrl(kIsWeb);
}
