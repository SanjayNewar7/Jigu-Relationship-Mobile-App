/// Converts the server's pairing outcome into an actionable message.
class SpaceJoinResult {
  static String? errorMessage(Map<String, dynamic> result) {
    switch (result['status']) {
      case 'joined':
        return null;
      case 'already_in_space':
        return 'Leave your current space in Settings before joining another.';
      case 'target_unavailable':
        return 'This person is still in another shared space. They need to leave it before you can pair.';
      case 'own_code':
        return 'That is your own code. Enter your partner\'s six digit code.';
      case 'rate_limited':
        final seconds = (result['retry_after_seconds'] as num?)?.toInt() ?? 600;
        final minutes = (seconds / 60).ceil().clamp(1, 10);
        return 'Too many attempts. Try again in $minutes ${minutes == 1 ? 'minute' : 'minutes'}.';
      case 'invalid_code':
        return 'That code was not found. Ask your partner to check their six digit code.';
      case 'profile_missing':
        return 'Your profile is not ready. Please reopen Jigu and try again.';
      default:
        return 'Unable to join this space. Please try again.';
    }
  }
}
