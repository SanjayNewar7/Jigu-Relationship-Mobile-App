/// Foreground chat route. Firebase still delivers pushes to the app; the
/// notification controller decides whether a visible banner is useful.
class ChatVisibility {
  static String? space;
  static bool Function()? isCurrent;

  static bool viewing(String? incomingSpace) =>
      (incomingSpace == null || incomingSpace == space) &&
      (isCurrent?.call() ?? false);

  static void clear(String chatSpace) {
    if (space == chatSpace) {
      space = null;
      isCurrent = null;
    }
  }
}
