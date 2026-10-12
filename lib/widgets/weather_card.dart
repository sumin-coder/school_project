import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/weather_service.dart';

class WeatherCard extends StatelessWidget {
  final WeatherData weather;
  final String tagText;

  const WeatherCard({
    super.key,
    required this.weather,
    this.tagText = '#가벼운 가디건 #캠퍼스 룩',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘 ${weather.cityName}의 날씨 ${weather.condition}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '${weather.temperature.toStringAsFixed(1)}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tagText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const Icon(Icons.wb_sunny_rounded, size: 60, color: Colors.white),
        ],
      ),
    );
  }
}
