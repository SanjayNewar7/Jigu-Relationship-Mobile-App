import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/config.dart';
import '../../../core/widgets/lily_bloom.dart';

Future<DateTime?> showLilyDatePicker(BuildContext context, DateTime initial) {
  final now = DateTime.now();
  var selected = initial.isAfter(now)
      ? initial
      : now.add(const Duration(hours: 1));
  var choosingTime = false;
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: coral.withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 14),
                const LilyBloom(size: 56),
                const Text(
                  'Save some time for us',
                  style: TextStyle(fontSize: 25, color: plum),
                ),
                const SizedBox(height: 6),
                Text(
                  '${MaterialLocalizations.of(context).formatMediumDate(selected)} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(selected))}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(CupertinoIcons.calendar),
                      label: Text('The day'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(CupertinoIcons.clock),
                      label: Text('The time'),
                    ),
                  ],
                  selected: {choosingTime},
                  onSelectionChanged: (value) =>
                      update(() => choosingTime = value.first),
                ),
                if (!choosingTime)
                  Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: coral,
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: selected,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: DateTime(now.year + 3),
                      onDateChanged: (day) => update(
                        () => selected = DateTime(
                          day.year,
                          day.month,
                          day.day,
                          selected.hour,
                          selected.minute,
                        ),
                      ),
                    ),
                  ),
                if (choosingTime)
                  SizedBox(
                    height: 230,
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(
                        primaryColor: coral,
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            fontFamily: 'Sniglet',
                            fontSize: 23,
                            color: plum,
                          ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: selected,
                        onDateTimeChanged: (time) => update(
                          () => selected = DateTime(
                            selected.year,
                            selected.month,
                            selected.day,
                            time.hour,
                            time.minute,
                          ),
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (!choosingTime) {
                        update(() => choosingTime = true);
                      } else {
                        Navigator.pop(context, selected);
                      }
                    },
                    child: Text(
                      choosingTime
                          ? 'Keep this lovely time'
                          : 'Choose our time',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
