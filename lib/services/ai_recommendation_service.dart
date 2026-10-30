import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cloth_item.dart';
import '../models/outfit_recommendation.dart';
import '../services/weather_service.dart';

class AiRecommendationService {
  static const String _favKey = 'style_pulse_fav_rec_titles';

  static String get apiKey {
    try {
      return utf8.decode(base64Decode('Z3NrX0tSRXRCQ0dWcTF6VEJmeU40UUlXR2Ryb0ZZN2ZhTnFsd0l0SlovNFB3QUM5aUdYbU0='));
    } catch (_) {
      return '';
    }
  }

  // ⚡ 속도 최적화: 메모리 캐시 (5분간 유지하여 즉각적인 응답 제공)
  static final Map<String, List<OutfitRecommendation>> _recommendationCache = {};
  static final Map<String, DateTime> _cacheTime = {};

  // 💖 영구 즐겨찾기 상태 동기화 및 토글 처리
  static Future<void> toggleRecommendationFavorite(OutfitRecommendation item) async {
    item.isFavorite = !item.isFavorite;
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> favs = prefs.getStringList(_favKey) ?? [];
      if (item.isFavorite) {
        if (!favs.contains(item.title)) favs.add(item.title);
      } else {
        favs.remove(item.title);
      }
      await prefs.setStringList(_favKey, favs);
    } catch (e) {
      debugPrint('추천 즐겨찾기 저장 에러: $e');
    }
  }

  static Future<void> syncFavoriteStates(List<OutfitRecommendation> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> favs = prefs.getStringList(_favKey) ?? [];
      for (final item in items) {
        if (favs.contains(item.title)) {
          item.isFavorite = true;
        }
      }
    } catch (_) {}
  }

  Future<List<OutfitRecommendation>> fetchAiRecommendations({
    required List<ClothItem> clothes,
    required WeatherData weather,
    required String selectedTpo,
    bool forceRefresh = false,
  }) async {
    if (clothes.isEmpty) {
      throw Exception('옷장에 등록된 옷이 부족합니다. 먼저 옷을 추가해 주세요!');
    }

    // 💖 즐겨찾기 수량 변경도 반영되도록 캐시 키 생성
    final favCount = clothes.where((c) => c.isFavorite).length;
    final cacheKey = '${clothes.length}_${favCount}_${selectedTpo}_${weather.temperature.round()}';

    // 캐시된 결과가 있고 5분 미만 경과했다면 0초 만에 응답 반환
    if (!forceRefresh &&
        _recommendationCache.containsKey(cacheKey) &&
        _cacheTime.containsKey(cacheKey)) {
      if (DateTime.now().difference(_cacheTime[cacheKey]!) < const Duration(minutes: 5)) {
        final cachedResults = _recommendationCache[cacheKey]!;
        await syncFavoriteStates(cachedResults);
        return cachedResults;
      }
    }

    // 💖 AI에게 즐겨찾기(찜)한 옷들을 명확하게 태깅하여 프롬프트 전달
    String clothesDescription = clothes.map((c) {
      final favTag = c.isFavorite ? ' [★사용자가 즐겨찾기 찜한 최우선 선호 의류]' : '';
      return "- [${c.category}] 이름: ${c.title} (색상: ${c.color})$favTag";
    }).join("\n");

    String prompt = '''
너는 전문 패션 스타일리스트 AI야. 아래 사용자 옷장 목록과 현재 날씨 정보를 바탕으로 맞춤형 코디 추천 3가지를 생성해줘.

[사용자 옷장 목록]
$clothesDescription

[현재 날씨 환경]
- 기온: ${weather.temperature}°C
- 날씨 상태: ${weather.translatedCondition}

[요청 조건]
- 상황(TPO): $selectedTpo (만약 '전체'라면 캐주얼, 데이트, 비즈니스 등 다양한 스타일로 골고루 섞어줘)
- ★최우선 가이드라인★: [사용자 옷장 목록]에서 [★사용자가 즐겨찾기 찜한 최우선 선호 의류] 표기가 된 옷들을 가능한 최우선으로 조합해서 코디를 만들어줘.
- 반드시 위의 [사용자 옷장 목록]에 있는 아이템 이름(title)들만 조합해서 상의(top), 하의(bottom), 아우터(outer), 신발(shoes)을 골라줘.
- 결과는 반드시 아래와 같은 순수 JSON 배열 형식으로만 응답해줘. (마크다운 백틱 ```json 등 다른 설명글은 절대 포함하지 말고 오직 JSON 배열만 출력할 것)

[
  {
    "id": "1",
    "title": "코디 제목",
    "tpo": "캐주얼",
    "weatherCondition": "${weather.translatedCondition}",
    "minTemp": 10,
    "maxTemp": 25,
    "top": "상의 이름",
    "bottom": "하의 이름",
    "outer": "아우터 이름 또는 없음",
    "shoes": "신발 이름",
    "aiReason": "추천 이유"
  }
]
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': 'You are a professional fashion stylist that outputs strict JSON array only.'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String content = data['choices'][0]['message']['content'];

        content = content.replaceAll(RegExp(r'```json|```', caseSensitive: false), '').trim();

        List<dynamic> jsonList = jsonDecode(content);

        final results = jsonList.map((item) => OutfitRecommendation(
          id: item['id']?.toString() ?? '1',
          title: item['title'] ?? '추천 코디',
          tpo: item['tpo'] ?? '캐주얼',
          weatherCondition: item['weatherCondition'] ?? weather.translatedCondition,
          minTemp: (item['minTemp'] as num?)?.toInt() ?? 10,
          maxTemp: (item['maxTemp'] as num?)?.toInt() ?? 30,
          top: item['top'] ?? '',
          bottom: item['bottom'] ?? '',
          outer: item['outer'] ?? '',
          shoes: item['shoes'] ?? '',
          aiReason: item['aiReason'] ?? 'AI가 추천하는 멋진 코디입니다.',
          isFavorite: false,
        )).toList();

        await syncFavoriteStates(results);

        _recommendationCache[cacheKey] = results;
        _cacheTime[cacheKey] = DateTime.now();

        return results;
      } else {
        debugPrint('AI API 응답 실패 (${response.statusCode}): ${response.body}');
        final fallbacks = _generateFallbackRecommendations(clothes, weather, selectedTpo);
        await syncFavoriteStates(fallbacks);
        return fallbacks;
      }
    } catch (e) {
      debugPrint('AI 추천 처리 중 예외 발생, 스마트 폴백 실행: $e');
      final fallbacks = _generateFallbackRecommendations(clothes, weather, selectedTpo);
      await syncFavoriteStates(fallbacks);
      return fallbacks;
    }
  }

  List<OutfitRecommendation> _generateFallbackRecommendations(
    List<ClothItem> clothes,
    WeatherData weather,
    String selectedTpo,
  ) {
    // 💖 즐겨찾기(찜) 등록된 옷들을 최우선 순위로 상단 정렬
    final sortedClothes = List<ClothItem>.from(clothes)
      ..sort((a, b) {
        if (a.isFavorite && !b.isFavorite) return -1;
        if (!a.isFavorite && b.isFavorite) return 1;
        return 0;
      });

    final tops = sortedClothes.where((c) => c.category == '상의').toList();
    final bottoms = sortedClothes.where((c) => c.category == '하의').toList();
    final outers = sortedClothes.where((c) => c.category == '아우터').toList();
    final shoesList = sortedClothes.where((c) => c.category == '신발/잡화').toList();

    String topName = tops.isNotEmpty ? tops.first.title : (sortedClothes.isNotEmpty ? sortedClothes.first.title : '니트');
    String bottomName = bottoms.isNotEmpty ? bottoms.first.title : '슬랙스';
    String outerName = (weather.temperature < 18 && outers.isNotEmpty) ? outers.first.title : '없음';
    String shoesName = shoesList.isNotEmpty ? shoesList.first.title : '스니커즈';

    String tpoLabel = selectedTpo == '전체' ? '캐주얼' : selectedTpo;

    final List<OutfitRecommendation> fallbacks = [
      OutfitRecommendation(
        id: '1',
        title: '${weather.translatedCondition} 날씨 추천 $tpoLabel 룩',
        tpo: tpoLabel,
        weatherCondition: weather.translatedCondition,
        minTemp: (weather.temperature - 3).round(),
        maxTemp: (weather.temperature + 5).round(),
        top: topName,
        bottom: bottomName,
        outer: outerName,
        shoes: shoesName,
        aiReason: '즐겨찾기한 의상들을 최우선 반영하여 현재 기온(${weather.temperature.toStringAsFixed(1)}°C)에 어울리는 최적의 룩을 완성했습니다.',
        isFavorite: false,
      ),
    ];

    if (tops.length > 1 || bottoms.length > 1) {
      fallbacks.add(
        OutfitRecommendation(
          id: '2',
          title: '선호 스타일 $tpoLabel 코디',
          tpo: selectedTpo == '전체' ? '비즈니스' : selectedTpo,
          weatherCondition: weather.translatedCondition,
          minTemp: (weather.temperature - 2).round(),
          maxTemp: (weather.temperature + 4).round(),
          top: tops.length > 1 ? tops[1].title : topName,
          bottom: bottoms.length > 1 ? bottoms[1].title : bottomName,
          outer: outers.length > 1 ? outers[1].title : outerName,
          shoes: shoesList.length > 1 ? shoesList[1].title : shoesName,
          aiReason: '옷장에서 자주 입고 좋아하는 의류들을 조합해 편안함과 스타일을 극대화했습니다.',
          isFavorite: false,
        ),
      );
    }

    return fallbacks;
  }
}
