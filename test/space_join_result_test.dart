import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/models/space_join_result.dart';

void main() {
  test('distinguishes unavailable partner from invalid invite', () {
    expect(SpaceJoinResult.errorMessage({'status': 'joined'}), isNull);
    expect(
      SpaceJoinResult.errorMessage({'status': 'target_unavailable'}),
      contains('They need to leave'),
    );
    expect(
      SpaceJoinResult.errorMessage({'status': 'invalid_code'}),
      contains('code was not found'),
    );
    expect(
      SpaceJoinResult.errorMessage({'status': 'own_code'}),
      contains('your own code'),
    );
  });
  test('rounds cooldown up so users do not retry too early', () {
    expect(
      SpaceJoinResult.errorMessage({
        'status': 'rate_limited',
        'retry_after_seconds': 61,
      }),
      contains('2 minutes'),
    );
    expect(
      SpaceJoinResult.errorMessage({
        'status': 'rate_limited',
        'retry_after_seconds': 1,
      }),
      contains('1 minute.'),
    );
  });
}
