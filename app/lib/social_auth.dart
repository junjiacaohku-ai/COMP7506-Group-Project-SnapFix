import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'api.dart';
import 'models.dart';

class SocialAuthService {
  SocialAuthService({required this.api});

  static const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  final ApiClient api;
  bool _googleInitialized = false;

  static bool get googleConfigured => _googleClientId.isNotEmpty;

  Future<AuthResult> signInWithApple() async {
    final nonce = await api.appleNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const ApiException('Apple 未返回有效的身份令牌');
    }
    final fullName = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().join(' ').trim();
    return api.loginWithApple(
      identityToken,
      nonce,
      fullName.isEmpty ? null : fullName,
    );
  }

  Future<AuthResult> signInWithGoogle() async {
    if (!googleConfigured) {
      throw const ApiException('Google 登录尚未配置 Client ID');
    }
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(
        clientId: _googleClientId,
        serverClientId: _googleServerClientId.isEmpty
            ? null
            : _googleServerClientId,
      );
      _googleInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final identityToken = account.authentication.idToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const ApiException('Google 未返回有效的身份令牌');
    }
    return api.loginWithGoogle(identityToken);
  }
}
