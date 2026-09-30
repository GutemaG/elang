// BeansStatus brought forward in time, refilled, and saved
// (013-stat-pill-interactions, bolt 060).

import 'package:elang/shared/models/beans_status.dart';
import 'package:flutter_test/flutter_test.dart';

final _next = DateTime.utc(2026, 9, 30, 12);

BeansStatus _status({int beans = 2, DateTime? next, int regen = 30}) =>
    BeansStatus(
      beans: beans,
      beansMax: 5,
      regenMinutesPerBean: regen,
      amoleBalance: 400,
      refillCostAmole: 350,
      nextBeanAt: next,
    );

void main() {
  group('at', () {
    test('before the next bean, nothing changes', () {
      final status = _status(next: _next);
      final later = status.at(_next.subtract(const Duration(seconds: 1)));
      expect(later.beans, 2);
      expect(later.nextBeanAt, _next);
    });

    test('at the next bean, one arrives and the one after is timed', () {
      final later = _status(next: _next).at(_next);
      expect(later.beans, 3);
      expect(later.nextBeanAt, _next.add(const Duration(minutes: 30)));
    });

    test('each whole period since brings one more', () {
      final later = _status(next: _next)
          .at(_next.add(const Duration(minutes: 61)));
      expect(later.beans, 5); // 2, and 3 more
      expect(later.nextBeanAt, isNull);

      final partway = _status(
        beans: 0,
        next: _next,
      ).at(_next.add(const Duration(minutes: 45)));
      expect(partway.beans, 2);
      expect(partway.nextBeanAt, _next.add(const Duration(minutes: 60)));
    });

    test('never goes past the maximum, and full has no next bean', () {
      final later = _status(next: _next).at(_next.add(const Duration(days: 2)));
      expect(later.beans, 5);
      expect(later.isFull, isTrue);
      expect(later.nextBeanAt, isNull);
    });

    test('full, untimed or rateless statuses stay as they are', () {
      final full = _status(beans: 5);
      expect(identical(full.at(_next), full), isTrue);
      final untimed = _status();
      expect(identical(untimed.at(_next), untimed), isTrue);
      final rateless = _status(next: _next, regen: 0);
      expect(rateless.at(_next.add(const Duration(hours: 1))).beans, 2);
    });

    test('keeps the Amole balance and the refill price', () {
      final later = _status(next: _next).at(_next);
      expect(later.amoleBalance, 400);
      expect(later.refillCostAmole, 350);
      expect(later.regenMinutesPerBean, 30);
    });
  });

  test('refilled takes the new beans and balance', () {
    final full = _status(next: _next)
        .refilled(const RefillSuccess(newBeans: 5, newAmoleBalance: 50));
    expect(full.beans, 5);
    expect(full.amoleBalance, 50);
    expect(full.nextBeanAt, isNull);

    final partial = _status(next: _next)
        .refilled(const RefillSuccess(newBeans: 4, newAmoleBalance: 50));
    expect(partial.nextBeanAt, _next);
  });

  group('json', () {
    test('round-trips', () {
      final back = BeansStatus.fromJson(_status(next: _next).toJson())!;
      expect(back.beans, 2);
      expect(back.beansMax, 5);
      expect(back.regenMinutesPerBean, 30);
      expect(back.amoleBalance, 400);
      expect(back.refillCostAmole, 350);
      expect(back.nextBeanAt, _next);
    });

    test('a full status has no next bean', () {
      expect(
        BeansStatus.fromJson(_status(beans: 5).toJson())!.nextBeanAt,
        isNull,
      );
    });

    test('anything else is null', () {
      expect(BeansStatus.fromJson(null), isNull);
      expect(BeansStatus.fromJson('beans'), isNull);
      expect(BeansStatus.fromJson(<String, dynamic>{'beans': 1}), isNull);
    });
  });
}
