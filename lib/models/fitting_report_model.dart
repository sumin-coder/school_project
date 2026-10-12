class FittingReportModel {
  final String recommendedSize;
  final String shoulderFit; // Tight / Perfect / Loose
  final String chestFit;    // Tight / Perfect / Loose
  final String lengthFit;   // Short / Regular / Long
  final String summary;
  final int fitScore;       // e.g. 92%

  FittingReportModel({
    required this.recommendedSize,
    required this.shoulderFit,
    required this.chestFit,
    required this.lengthFit,
    required this.summary,
    required this.fitScore,
  });

  factory FittingReportModel.fromJson(Map<String, dynamic> json) {
    return FittingReportModel(
      recommendedSize: json['recommendedSize'] ?? 'M',
      shoulderFit: json['shoulderFit'] ?? 'Perfect',
      chestFit: json['chestFit'] ?? 'Perfect',
      lengthFit: json['lengthFit'] ?? 'Regular',
      summary: json['summary'] ?? '가슴과 어깨 라인이 잘 맞고 편안한 핏을 제공합니다.',
      fitScore: (json['fitScore'] as num?)?.toInt() ?? 95,
    );
  }
}
