// Mobile / desktop implementation — uses service account auth.
import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

final Map<String, dynamic> _serviceAccountConfig = {
  "type": "service_account",
  "project_id": const String.fromEnvironment('GCP_PROJECT_ID', defaultValue: 'llminfabula-1'),
  "private_key_id": const String.fromEnvironment('GCP_PRIVATE_KEY_ID', defaultValue: 'YOUR_PRIVATE_KEY_ID'),
  "private_key": const String.fromEnvironment('GCP_PRIVATE_KEY', defaultValue: 'YOUR_PRIVATE_KEY'),
  "client_email": const String.fromEnvironment('GCP_CLIENT_EMAIL', defaultValue: 'YOUR_SERVICE_ACCOUNT_EMAIL'),
  "client_id": const String.fromEnvironment('GCP_CLIENT_ID', defaultValue: ''),
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "",
  "universe_domain": "googleapis.com",
};

Future<http.Response> postWithServiceAccount({
  required String url,
  required Map<String, dynamic> body,
}) async {
  final privateKey = _serviceAccountConfig['private_key']?.toString() ?? '';
  if (privateKey.contains('YOUR_PRIVATE_KEY') || privateKey.isEmpty) {
    throw UnsupportedError(
      'Google Cloud Service Account credentials are not configured. Note: On Web, the browser-native Web Speech API is used instead.',
    );
  }

  final accountCredentials =
      ServiceAccountCredentials.fromJson(_serviceAccountConfig);
  final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
  final authClient =
      await clientViaServiceAccount(accountCredentials, scopes);
  try {
    final response = await authClient.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    return response;
  } finally {
    authClient.close();
  }
}

Future<String?> saveTempAudio(String base64Audio) async {
  final bytes = base64Decode(base64Audio);
  final dir = await getTemporaryDirectory();
  final fileName = 'tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

void speakWeb(String text, String narratorId) {
  // No-op on mobile/desktop (mobile uses native AudioPlayer).
}

void stopWeb() {
  // No-op on mobile/desktop.
}

