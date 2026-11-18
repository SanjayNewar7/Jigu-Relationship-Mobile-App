import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';

class AuthService {
  Future<void> deleteAccount(String password) async {
    final result = await db.functions.invoke(
      'delete-account',
      body: {'password': password, 'confirmation': 'DELETE'},
    );
    if (result.status != 200 ||
        result.data is! Map ||
        result.data['deleted'] != true) {
      throw StateError('Deletion could not finish. Please try again.');
    }
  }

  Future<void> sendPasswordReset(String email) =>
      db.auth.resetPasswordForEmail(email, redirectTo: authRedirectUrl);

  Future<void> changePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    if (currentPassword != null) {
      final email = db.auth.currentUser?.email;
      if (email == null) {
        throw StateError('Sign in again to change your password.');
      }
      final verifier = SupabaseClient(url, key);
      try {
        final response = await verifier.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
        if (response.user?.id != db.auth.currentUser?.id) {
          throw StateError('Current password could not be verified.');
        }
      } finally {
        verifier.dispose();
      }
    }
    await db.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<AuthResponse> signUp(String email, String password) => db.auth.signUp(
    email: email,
    password: password,
    emailRedirectTo: authRedirectUrl,
  );

  Future<AuthResponse> signIn(String email, String password) =>
      db.auth.signInWithPassword(email: email, password: password);

  Future<ResendResponse> resendConfirmation(String email) => db.auth.resend(
    type: OtpType.signup,
    email: email,
    emailRedirectTo: authRedirectUrl,
  );
}
