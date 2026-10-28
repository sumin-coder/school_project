import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_colors.dart';
import '../models/cloth_item.dart';
import '../models/outfit_recommendation.dart';
import '../services/weather_service.dart';
import '../services/ai_recommendation_service.dart';
import '../widgets/home/weather_banner_card.dart';
import '../widgets/home/home_ai_curation_card.dart';
import '../widgets/home/recent_clothes_section.dart';

class HomeScreen extends StatefulWidget {
  final Function(int index)? onTabChange;
  final List<ClothItem> recentItems;

  const HomeScreen({
    super.key,
    this.onTabChange,
    this.recentItems = const [],
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<WeatherData> _weatherFuture;
  final WeatherService _weatherService = WeatherService();
  final AiRecommendationService _aiService = AiRecommendationService();

  OutfitRecommendation? _topRecommendation;
  bool _isAiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _determinePositionAndFetchWeather();
    _loadAiRecommendation();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recentItems.length != widget.recentItems.length) {
      _loadAiRecommendation();
    }
  }

  Future<void> _loadAiRecommendation() async {
    if (widget.recentItems.isEmpty) {
      if (mounted) {
        setState(() {
          _topRecommendation = null;
          _aiError = '옷장에 옷이 없습니다.\n새 옷을 등록하면 AI가 맞춤 코디를 추천해 드립니다!';
          _isAiLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isAiLoading = true;
      _aiError = null;
    });

    try {
      final weather = await _weatherFuture;
      final results = await _aiService.fetchAiRecommendations(
        clothes: widget.recentItems,
        weather: weather,
        selectedTpo: '전체',
      );

      if (!mounted) return;
      setState(() {
        _topRecommendation = results.isNotEmpty ? results.first : null;
        _isAiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAiLoading = false;
        _aiError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<WeatherData> _determinePositionAndFetchWeather() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return await _weatherService.fetchWeatherByCoordinates(34.7606, 127.6622);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return await _weatherService.fetchWeatherByCoordinates(34.7606, 127.6622);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return await _weatherService.fetchWeatherByCoordinates(34.7606, 127.6622);
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 3));

      if (position.latitude > 30.0 && position.latitude < 40.0 && position.longitude < -100.0) {
        return await _weatherService.fetchWeatherByCoordinates(34.7606, 127.6622);
      }

      return await _weatherService.fetchWeatherByCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      return await _weatherService.fetchWeatherByCoordinates(34.7606, 127.6622);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WeatherBannerCard(weatherFuture: _weatherFuture),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text(
                      '오늘의 AI 큐레이션',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.auto_awesome, color: AppColors.goldAccent, size: 20),
                  ],
                ),
                TextButton(
                  onPressed: () => widget.onTabChange?.call(2),
                  child: const Text(
                    '전체보기',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            HomeAiCurationCard(
              recommendation: _topRecommendation,
              recentItems: widget.recentItems,
              isLoading: _isAiLoading,
              errorMessage: _aiError,
              onRefresh: _loadAiRecommendation,
              onTabChange: widget.onTabChange,
            ),
            const SizedBox(height: 24),
            RecentClothesSection(
              items: widget.recentItems,
              onTabChange: widget.onTabChange,
            ),
          ],
        ),
      ),
    );
  }
}
