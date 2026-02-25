import 'dart:io';

String getApiBaseUrl(bool kIsWeb) {
  if (kIsWeb) return 'http://localhost:5186';
  if (Platform.isAndroid) return 'http://10.0.2.2:5186';
  return 'http://localhost:5186';
}
