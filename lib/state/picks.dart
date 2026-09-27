import '../mock/models.dart';

/// "Find Your Right Doctor": OPflow's paid, one-time suggestion of up to 3 doctors of one type near the patient.
/// The doctors are picked by OPflow (never paid for by doctors), from published criteria.

/// The Home card: on or off, and the price the admin set.
class PickInfo {
  const PickInfo({required this.enabled, required this.pricePaise, required this.priceText, this.max = 3});

  final bool enabled;
  final int pricePaise;
  final String priceText;
  final int max;
}

/// Before paying: how OPflow recommends, and how many doctors it can suggest near the patient (0 = don't pay).
class PickOffer {
  const PickOffer({
    required this.enabled,
    required this.typeId,
    required this.typeName,
    required this.pricePaise,
    required this.priceText,
    required this.criteria,
    required this.available,
    this.max = 3,
  });

  final bool enabled;
  final String typeId;
  final String typeName;
  final int pricePaise;
  final String priceText;
  final String criteria;
  final int available;
  final int max;
}

/// One suggested doctor, with the reasons OPflow shows.
class PickDoctor {
  const PickDoctor({required this.doctor, required this.reasons, required this.distanceKm});

  final Doctor doctor;
  final List<String> reasons;
  final double distanceKm;
}

/// A bought suggestion (a saved snapshot: it never changes).
class PickResult {
  const PickResult({
    required this.id,
    required this.typeId,
    required this.typeName,
    required this.status,
    required this.doctors,
    this.place,
    this.paidAt,
    this.amountText = '',
    this.refundReason,
  });

  final String id;
  final String typeId;
  final String typeName;

  /// 'paid' | 'refunded' | 'pending_payment' | 'failed'
  final String status;
  final List<PickDoctor> doctors;
  final String? place;
  final DateTime? paidAt;
  final String amountText;
  final String? refundReason;

  bool get paid => status == 'paid';
  bool get refunded => status == 'refunded';
}

/// A line in Me → My doctor suggestions.
class PickSummary {
  const PickSummary({required this.id, required this.typeId, required this.typeName, required this.status, required this.count, this.place, this.paidAt});

  final String id;
  final String typeId;
  final String typeName;
  final String status;
  final int count;
  final String? place;
  final DateTime? paidAt;
}
