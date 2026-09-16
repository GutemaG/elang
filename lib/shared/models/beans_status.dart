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
