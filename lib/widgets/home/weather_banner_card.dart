import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/weather_service.dart';

class WeatherBannerCard extends StatelessWidget {
  final Future<WeatherData> weatherFuture;

  const WeatherBannerCard({
    super.key,
    required this.weatherFuture,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<WeatherData>(
      future: weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.darkContainerBackground : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '날씨 정보를 불러오지 못했습니다.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        final weather = snapshot.data!;

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
                    '오늘 ${weather.cityName}의 날씨 ${weather.translatedCondition}',
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
                    child: const Text(
                      '#오늘의추천룩 #스타일펄스',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Icon(Icons.wb_sunny_rounded, size: 60, color: Colors.white),
            ],
          ),
        );
      },
    );
  }
}
