import 'package:flutter_test/flutter_test.dart';

import 'package:trackit_mobile/utils/philippines_time.dart';

void main() {
  test('parses epoch millis and seconds', () {
    expect(PhilippinesTime.parseMillis(1725000000000), 1725000000000);
    expect(PhilippinesTime.parseMillis(1725000000), 1725000000000);
    expect(PhilippinesTime.parseMillis({'_seconds': 1725000000}), 1725000000000);
  });

  test('converts UTC millis to Asia/Manila wall clock', () {
    final noonPh = PhilippinesTime.dateTime(DateTime.utc(2026, 9, 7, 4, 30).millisecondsSinceEpoch);
    expect(noonPh.hour, 12);
    expect(noonPh.minute, 30);
    expect(noonPh.day, 7);
  });
}
