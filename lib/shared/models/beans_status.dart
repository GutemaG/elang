/// The account's current beans/refill state, shown by the out-of-beans
/// modal (story 003) and the dashboard HUD.
class BeansStatus {
  const BeansStatus({
    required this.beans,
    required this.beansMax,
    required this.regenMinutesPerBean,
    required this.amoleBalance,
    required this.refillCostAmole,
    this.nextBeanAt,
  });

  final int beans;
  final int beansMax;

  /// `null` when beans are already full — nothing is regenerating.
  final DateTime? nextBeanAt;
  final int regenMinutesPerBean;

  final int amoleBalance;
  final int refillCostAmole;

  bool get canAffordRefill => amoleBalance >= refillCostAmole;

  bool get isFull => beans >= beansMax;

  /// This status as it stands at [now] (013-stat-pill-interactions, bolt
  /// 060): each whole [regenMinutesPerBean] since [nextBeanAt] brought a
  /// bean, up to the maximum. The server regenerates the same way, lazily
  /// on read, so a stale copy -- a sheet left open, or the offline copy --
  /// shows what the server would say now.
  BeansStatus at(DateTime now) {
    final next = nextBeanAt;
    final period = Duration(minutes: regenMinutesPerBean);
    if (next == null ||
        isFull ||
        now.isBefore(next) ||
        period <= Duration.zero) {
      return this;
    }
    final arrived =
        1 + now.difference(next).inMicroseconds ~/ period.inMicroseconds;
    final nowBeans = beans + arrived > beansMax ? beansMax : beans + arrived;
    return _with(
      beans: nowBeans,
      nextBeanAt: nowBeans >= beansMax ? null : next.add(period * arrived),
    );
  }

  /// After a successful Amole refill.
  BeansStatus refilled(RefillSuccess result) => _with(
    beans: result.newBeans,
    amoleBalance: result.newAmoleBalance,
    nextBeanAt: result.newBeans >= beansMax ? null : nextBeanAt,
  );

  BeansStatus _with({
    required int beans,
    required DateTime? nextBeanAt,
    int? amoleBalance,
  }) => BeansStatus(
    beans: beans,
    beansMax: beansMax,
    regenMinutesPerBean: regenMinutesPerBean,
    amoleBalance: amoleBalance ?? this.amoleBalance,
    refillCostAmole: refillCostAmole,
    nextBeanAt: nextBeanAt,
  );

  /// For the dashboard's offline copy.
  Map<String, dynamic> toJson() => {
    'beans': beans,
    'beans_max': beansMax,
    'regen_minutes_per_bean': regenMinutesPerBean,
    'amole_balance': amoleBalance,
    'refill_cost_amole': refillCostAmole,
    'next_bean_at': nextBeanAt?.toUtc().toIso8601String(),
  };

  /// `null` for anything that is not a saved status.
  static BeansStatus? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final beans = raw['beans'];
    final max = raw['beans_max'];
    final regen = raw['regen_minutes_per_bean'];
    final amole = raw['amole_balance'];
    final cost = raw['refill_cost_amole'];
    final next = raw['next_bean_at'];
    if (beans is! int ||
        max is! int ||
        regen is! int ||
        amole is! int ||
        cost is! int) {
      return null;
    }
    return BeansStatus(
      beans: beans,
      beansMax: max,
      regenMinutesPerBean: regen,
      amoleBalance: amole,
      refillCostAmole: cost,
      nextBeanAt: next is String ? DateTime.tryParse(next) : null,
    );
  }
}

/// Why an Amole refill attempt didn't succeed.
enum RefillFailureReason {
  /// The account doesn't have enough Amole — the refill action should be
  /// disabled before this can even be attempted (see story 003's edge
  /// case), but the API still reports it explicitly rather than failing
  /// silently.
  insufficientAmole,
}

sealed class RefillResult {
  const RefillResult();
}

class RefillSuccess extends RefillResult {
  const RefillSuccess({required this.newBeans, required this.newAmoleBalance});

  final int newBeans;
  final int newAmoleBalance;
}

class RefillFailure extends RefillResult {
  const RefillFailure(this.reason);

  final RefillFailureReason reason;
}
