import '../core/errors/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String authErrorMessage(Object error) {
  if (error is! AuthException) return AppError.message(error);
  final connection = AppError.message(error, fallback: '');
  if (connection.isNotEmpty) return connection;
  switch (error.code) {
    case 'otp_expired':
      return 'This link was already used or has expired. If you already confirmed your email, sign in. Otherwise, request a fresh confirmation below.';
    case 'flow_state_not_found':
    case 'flow_state_expired':
    case 'bad_code_verifier':
      return 'Your email may already be confirmed. Try signing in here with your password. Open new confirmation links on the phone where you requested them.';
    case 'email_address_not_authorized':
      return 'Verification email cannot be sent to this address yet. Please contact Jigu support.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'Too many email requests. Please wait before requesting another. If you already confirmed, sign in.';
    case 'email_not_confirmed':
      return 'Confirm your email first. You can request a fresh confirmation below.';
    case 'invalid_credentials':
      return 'The email or password is incorrect.';
    case 'user_already_exists':
      return 'This email already has an account. Sign in instead.';
    case 'email_address_invalid':
      return 'Enter a valid personal email address.';
    default:
      return 'Could not finish signing in. Please try again or contact Jigu support.';
  }
}
