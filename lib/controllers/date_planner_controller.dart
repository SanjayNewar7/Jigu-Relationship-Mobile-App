import 'package:flutter/foundation.dart';
import '../core/errors/app_error.dart';
import '../models/date_invitation.dart';
import '../services/date_planner_service.dart';

class DatePlannerController extends ChangeNotifier {
  DatePlannerController(this.coupleId);
  final String coupleId;
  final service = DatePlannerService();
  List<DateInvitation> invitations = [];
  int page = 0;
  bool history = false, hasNext = false;
  bool loading = false;
  bool pendingRefresh = false;
  bool disposed = false;
  String? error;
  Future<void> refresh() async {
    if (loading) {
      pendingRefresh = true;
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final rows = await service.load(coupleId, page: page, history: history);
      hasNext = rows.length > 10;
      invitations = rows.take(10).toList();
      error = null;
    } catch (e) {
      error = AppError.message(
        e,
        fallback: 'Could not load your invitations. Pull down to retry.',
      );
    } finally {
      loading = false;
      if (!disposed) notifyListeners();
      if (pendingRefresh && !disposed) {
        pendingRefresh = false;
        await refresh();
      }
    }
  }

  Future<void> changePage(int value) async {
    if (loading || value < 0) return;
    page = value;
    await refresh();
  }

  Future<void> changeSection(bool value) async {
    if (loading) return;
    history = value;
    page = 0;
    await refresh();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
