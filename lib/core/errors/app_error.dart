import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts transport and service failures into safe, actionable UI text.
class AppError {
  static String message(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final text = error.toString().toLowerCase();
    if (error is SocketException ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('network request failed') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('connection closed') ||
        text.contains('xmlhttprequest error')) {
      return 'No internet connection. Please connect to the internet and try again.';
    }
    if (error is TimeoutException || text.contains('timed out')) {
      return 'The connection is taking too long. Please check your internet and retry.';
    }
    if (error is AuthException &&
        (error.statusCode == '401' ||
            error.code == 'refresh_token_not_found')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (error is PostgrestException) {
      if (error.code == '42501') {
        return 'You no longer have access to this shared space. Please refresh.';
      }
      if (error.code == '23505') {
        return 'This has already been saved. Refresh to see the latest version.';
      }
    }
    if (text.contains('429')) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (error is StateError) {
      final message = error.message.toString();
      if (const [
        'Choose a ',
        'This attachment has expired',
        'Allow ',
        'Please sign in',
        'Sign in ',
        'Current password could not',
        'Only the person',
        'Calls are not configured',
        'Call service is unavailable',
        'A call is already in progress',
        'Call unavailable',
        'Your person has not joined',
        'Join your shared space',
        'Please wait a moment before calling',
        'Could not render',
        'Could not encode',
        'Deletion could not',
      ].any(message.startsWith)) {
        return message;
      }
    }
    if (error is FormatException &&
        (error.message.startsWith('Enter the six digit') ||
            error.message.startsWith('Use a name between') ||
            error.message.startsWith('Describe the concern'))) {
      return error.message;
    }
    return fallback;
  }
}
