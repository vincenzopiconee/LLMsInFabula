// Mobile / desktop implementation — uses service account auth.
import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

final Map<String, dynamic> _serviceAccountConfig = {
  "type": "service_account",
  "project_id": "llminfabula-1",
  "private_key_id": "60fa912bb1bbc8a1e753813a3b9a4af4d615c29d",
  "private_key":
      "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC4WLMzQjdY0S0/\nqajsRqcsP7BBuK1XXqcZNibW5OIo+pcWdM6eqUwH1HpywUEUTPbbBsKlr8OJrlfm\nHCqu9DXBaoH+RBFl3BjvvpyNBJqWQma2Kxmy6IFc1xB2awksgIcc0pNnU05djhOj\nuaY2q246sPKSGbrwBemSoQGeHsPN6jw7br9pT3rbeypEkTEtBxr81+nghpSEZWlC\nv2xmyiSYpx8D7ICrY0SsfenUwOr9crVH+vdHJdH7iuyNs5Btk5cT+OYjjHioImGA\nunFhIF88b05peoeeT/BF0mCRF0/rqeW2uk7EkzsZwZIuHa1SzLuwUp0G2+PIxhHS\nPtJa6dc3AgMBAAECggEAOSrMm6s/pavsl88Bww/f/MFdY+wk2TDRqehYoBCHsASS\nARVFE//VQ6JZPKgAig6aCO8uQppgjZxCxunaNLonx2zDljm+mXNpSkO2oaaZV9qM\nppZ0GD6xCzzoboif5iyPedk1e/fiF/Ic1guW52I/QzUnbDZNeeyjc+S5LzNELmEb\nNZbhlWI1ayK06IPoP/HTewH8qOi8xM0EAsAERpzPNqZOcwGbsxiZMqr8OA2ky8Bf\nn7qk56qhzpwAkkEC+3bxApIf1luF0c3Jl62eXopHsFYI1jKQ2GJzNFmPMxCRT/ij\nxugDNCYeOoOzXWQtisGXC5g3DVIvgVtCIbWjGmu7OQKBgQDyR2dkqdcrD35MB8j5\nIA8ABjK24BBVBmM5557PXJz0Y/UL8lHbdzn95KsGiHKDiq/U3y3QREuA6r8TEHMP\n8xnxiailFRcyu8cmfnYKN5rpmn4/EM83eLOnvgp0+P2iAW/ShdwAuMu5XKwyUsNE\nDSmnfwfe+DUN0VyfDasZF2e17wKBgQDCyWIJ/w1cASrmjFRsrf+tNuFc9hPc21Si\n2p67rbM1Vt52YuSu+2/BUEbWfLjBlQVa2zW0txEkZw0yWKimqg1c/fOkLThMebqm\nAHtvd6kKgZqvbEbIJVEqGBSPxBBtz+a6jOsNB0Wo6uc8Yndjxksj/58kS1ZkWp98\nhI2d6p/7OQKBgFGxRempYwX/+WQFk/x8lNI7RMppDti8iKSzttbQsZOuSKg4kuVf\ndExp2EkhpQs5rkQm5Lm+7X6QqNDy0PllzS+mbRkM3X+b1XDjX0XerftqvnrhXh2k\nM1+yMrBybIM93MitnhsYNIlR+DYXtgOyNINnz+2c37bDC2oOH80cGTo9AoGAH8vT\nzyHtQlmGcT/zABKfK91LiGs67tB2zma1hpliKZDWm6ik/9NXeMzr41NUrXTv/NbP\nu4IusCyKQO+sCBi2ObnSrbgb+o/cYgCuJZH47Bgf8gbQvxcoWqC3qogszmAjn8wl\nCmlne51sxbSlHIpf9a5iggAySAtrAV55549HMjECgYB5RPH/nKZymMpXyLbECQoG\nWFc+jP/eGNDbeSFWvTDh/mbLeLx629rSi2xRDmzpwDyZMmGGGs89NXrpzGViv/aD\n71YprML9bCBCmzZP2iLrvI3kkhfFma4ZRo3DGrLgLXfIgViDe0A3dakEYYTo/40A\n9BoKk/zWAfGD8D/Is7/mTA==\n-----END PRIVATE KEY-----\n",
  "client_email": "179744805366-compute@developer.gserviceaccount.com",
  "client_id": "111552661540605499686",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url":
      "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url":
      "https://www.googleapis.com/robot/v1/metadata/x509/179744805366-compute%40developer.gserviceaccount.com",
  "universe_domain": "googleapis.com",
};

Future<http.Response> postWithServiceAccount({
  required String url,
  required Map<String, dynamic> body,
}) async {
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

