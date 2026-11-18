import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jigulove/features/date_planner/widgets/date_place_map_picker.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('pin picker permits two-finger zoom without a drag exception', (tester) async {
    LatLng? chosen;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: DatePlaceMapPicker(onChanged: (point) => chosen = point),
    ))));
    await tester.pump();
    final map = find.byType(FlutterMap);
    expect(map, findsOneWidget);
    final options = tester.widget<FlutterMap>(map).options;
    expect(options.minZoom, 3);
    expect(options.maxZoom, 19);

    final center = tester.getCenter(map);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 350));
    expect(chosen, isNotNull);

    final first = await tester.startGesture(center + const Offset(-45, 0), pointer: 1);
    final second = await tester.startGesture(center + const Offset(45, 0), pointer: 2);
    await tester.pump();
    await first.moveTo(center + const Offset(-15, 0));
    await second.moveTo(center + const Offset(15, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
