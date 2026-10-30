import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_colors.dart';
import '../models/cloth_item.dart';
import '../models/outfit_recommendation.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/dialogs/virtual_fitting_dialog.dart';
import '../services/weather_service.dart';
import '../services/ai_recommendation_service.dart';
import 'avatar_fitting_screen.dart';

class RecommendScreen extends StatefulWidget {
  final List<ClothItem> clothes;

  const RecommendScreen({
    super.key,
    this.clothes = const [],
  });

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  String _selectedTpo = '전체';
  final List<String> _tpoList = ['전체', '캐주얼', '비즈니스', '데이트', '운동'];

  late Future<WeatherData> _weatherFuture;
  final WeatherService _weatherService = WeatherService();
  final AiRecommendationService _aiService = AiRecommendationService();

  List<OutfitRecommendation> _recommendations = [];
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _determinePositionAndFetchWeather();
    _loadAiRecommendationsOnStart();
  }

  Future<void> _loadAiRecommendationsOnStart() async {
    if (widget.clothes.isEmpty) {
      setState(() {
        _errorMessage = '옷장에 등록된 옷이 부족합니다.\n먼저 옷을 추가해 주세요!';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      WeatherData weather = await _weatherFuture;
      List<OutfitRecommendation> results = await _aiService.fetchAiRecommendations(
        clothes: widget.clothes,
        weather: weather,
        selectedTpo: _selectedTpo,
      );

      if (!mounted) return;
      setState(() {
        _recommendations = results;
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
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

      return await _weatherService.fetchWeatherByCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      return await _weatherService.fetchWeatherByCoordinates(34.7606, 127.6622);
    }
  }

  void _refreshRecommendation() async {
    if (widget.clothes.isEmpty) {
      setState(() {
        _errorMessage = '옷장에 등록된 옷이 부족합니다.\n먼저 옷을 추가해 주세요!';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      WeatherData weather = await _weatherFuture;
      List<OutfitRecommendation> results = await _aiService.fetchAiRecommendations(
        clothes: widget.clothes,
        weather: weather,
        selectedTpo: _selectedTpo,
        forceRefresh: true,
      );

      if (!mounted) return;

      setState(() {
        _recommendations = results;
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ AI가 옷장과 날씨를 분석하여 새로운 코디를 완성했습니다!'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final filteredList = _selectedTpo == '전체'
        ? _recommendations
        : _recommendations.where((item) => item.tpo == _selectedTpo).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 맞춤 코디 추천'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_esports),
            tooltip: '3D 아바타 피팅룸',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AvatarFittingScreen(clothes: widget.clothes),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.accessibility_new),
            tooltip: 'AI 3D 가상 피팅',
            onPressed: () => VirtualFittingDialog.show(context: context),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI 코디 생성',
            onPressed: _refreshRecommendation,
          ),
        ],
      ),
      body: _isGenerating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'AI가 옷장의 옷들과 날씨를 분석하고 있습니다...',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<WeatherData>(
                    future: _weatherFuture,
                    builder: (context, snapshot) {
                      String tempStr = '--°C';
                      String statusStr = '로딩 중';

                      if (snapshot.hasData) {
                        tempStr = '${snapshot.data!.temperature.toStringAsFixed(1)}°C';
                        statusStr = snapshot.data!.translatedCondition;
                      }

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryOrange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.wb_sunny,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '오늘의 스타일 환경',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$tempStr / $statusStr',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'AI가 현재 온도와 상황을 고려하여 옷장에서 최적의 조합을 제안합니다.',
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '어떤 상황의 옷을 찾으시나요?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _tpoList.map((tpo) {
                        final isSelected = _selectedTpo == tpo;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(tpo),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDarkMode ? Colors.grey[300] : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTpo = tpo;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '추천 코디 (${filteredList.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _refreshRecommendation,
                        icon: const Icon(
                          Icons.refresh,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'AI 새로고침',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.orangeAccent),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredList.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40.0),
                              child: Center(
                                child: Text(
                                  '해당 상황($_selectedTpo)에 맞는 AI 코디가 없습니다.',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final item = filteredList[index];
                                return RecommendationCard(
                                  item: item,
                                  clothes: widget.clothes,
                                  onFavoriteToggle: () async {
                                    await AiRecommendationService.toggleRecommendationFavorite(item);
                                    if (mounted) setState(() {});
                                  },
                                );
                              },
                            ),
                ],
              ),
            ),
    );
  }
}
