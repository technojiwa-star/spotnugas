/// Weights for the SpotNugas study score. They should sum to 1.0.
class StudyScoreWeights {
  final double wifi;
  final double outlet;
  final double comfort;
  final double noise;
  final double priceValue;
  final double reputation;

  const StudyScoreWeights({
    this.wifi = 0.25,
    this.outlet = 0.20,
    this.comfort = 0.20,
    this.noise = 0.15,
    this.priceValue = 0.10,
    this.reputation = 0.10,
  });

  static const StudyScoreWeights standard = StudyScoreWeights();
}

/// Small, deterministic, client-side study score helper.
///
/// This is NOT the production scoring backend. Curated / server-computed
/// `studyScore` values always take precedence; this is only a fallback for
/// places that have sub-scores but no stored overall score.
class StudyScoreCalculator {
  final StudyScoreWeights weights;

  const StudyScoreCalculator({this.weights = StudyScoreWeights.standard});

  static const double maxSubScore = 5.0;
  static const double maxStudyScore = 10.0;

  /// Combines 0–5 sub-scores (and a 0–5 rating as reputation) into a 0–10
  /// score rounded to one decimal.
  ///
  /// Missing components are skipped and the remaining weights renormalised.
  /// Returns `null` when no productivity sub-score is available — a rating
  /// alone says nothing about how good a place is for studying.
  double? compute({
    double? wifiScore,
    double? outletScore,
    double? comfortScore,
    double? noiseScore,
    double? priceValueScore,
    double? rating,
  }) {
    final productivity = <(double?, double)>[
      (wifiScore, weights.wifi),
      (outletScore, weights.outlet),
      (comfortScore, weights.comfort),
      (noiseScore, weights.noise),
      (priceValueScore, weights.priceValue),
    ];
    if (productivity.every((c) => c.$1 == null)) return null;

    var weighted = 0.0;
    var totalWeight = 0.0;
    for (final (value, weight) in [
      ...productivity,
      (rating, weights.reputation),
    ]) {
      if (value == null) continue;
      weighted += value.clamp(0.0, maxSubScore) * weight;
      totalWeight += weight;
    }
    if (totalWeight == 0) return null;

    final outOfTen = (weighted / totalWeight) / maxSubScore * maxStudyScore;
    return (outOfTen * 10).round() / 10;
  }

  /// Indonesian descriptor for a 0–10 study score.
  static String labelFor(double? score) {
    if (score == null) return 'Belum Dinilai';
    if (score >= 9.5) return 'Luar Biasa';
    if (score >= 9.2) return 'Sangat Direkomendasikan';
    if (score >= 9.0) return 'Sangat Bagus';
    if (score >= 8.5) return 'Bagus Sekali';
    if (score >= 7.5) return 'Bagus';
    if (score >= 6.0) return 'Cukup';
    return 'Kurang Cocok';
  }
}
