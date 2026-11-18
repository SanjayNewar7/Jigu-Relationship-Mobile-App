import '../core/config.dart';

class ProfileService {
  Future<String> renamePartner(String name) async =>
      await db.rpc('rename_partner', params: {'partner_name': name}) as String;

  Future<String?> name() async {
    final id = db.auth.currentUser?.id;
    if (id == null) return null;
    final row = await db
        .from('profiles')
        .select('display_name')
        .eq('id', id)
        .single();
    return row['display_name'] as String?;
  }

  Future<void> saveName(String value) async {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2 ||
        name.length > 40 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      throw const FormatException('Use a name between 2 and 40 characters.');
    }
    final id = db.auth.currentUser?.id;
    if (id == null) throw StateError('Please sign in again.');
    await db.from('profiles').update({'display_name': name}).eq('id', id);
  }
}
