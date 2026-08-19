import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app/app.dart';
import 'services/deep_link_service.dart';

/// Web OAuth client from android/app/google-services.json (oauth_client,
/// client_type 3) — google_sign_in needs this to request an ID token that
/// Firebase Auth can verify.
const _googleServerClientId =
    '80825860123-4m3do6c31ussrehsrh37528uia1jkhiq.apps.googleusercontent.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId);
  DeepLinkService.instance.initialize();
  runApp(const SawataApp());
}
