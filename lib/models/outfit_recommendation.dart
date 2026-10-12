class OutfitRecommendation {
  final String id;
  final String title;
  final String tpo;
  final String weatherCondition;
  final int minTemp;
  final int maxTemp;
  final String top;
  final String bottom;
  final String outer;
  final String shoes;
  final String aiReason;
  bool isFavorite;

  OutfitRecommendation({
    required this.id,
    required this.title,
    required this.tpo,
    required this.weatherCondition,
    required this.minTemp,
    required this.maxTemp,
    required this.top,
    required this.bottom,
    required this.outer,
    required this.shoes,
    required this.aiReason,
    this.isFavorite = false,
  });
}