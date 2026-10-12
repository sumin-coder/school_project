import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/cloth_item.dart';
import '../models/outfit_recommendation.dart';
import '../services/weather_service.dart';

class AiRecommendationService {
  static String get apiKey {
    try {
      return utf8.decode(base64Decode('QVEuQWI4Uk42TDF1bUd1dXlXTHlLcFgtNXF0bi0xb1k4cXd3ODZRZzRwaVBON0ZYOW1ybEE='));
    } catch (_) {
      return '';
    }
  }

  // ⚡ 속도 최적화: 메모리 캐시 (5분간 유지하여 즉각적인 응답 제공)
  static final Map<String, List<OutfitRecommendation>> _recommendationCache = {};
  static final Map<String, DateTime> _cacheTime = {};

  Future<List<OutfitRecommendation>> fetchAiRecommendations({
    required List<ClothItem> clothes,
    required WeatherData weather,
    required String selectedTpo,
    bool forceRefresh = false,
  }) async {
    if (clothes.isEmpty) {
      throw Exception('옷장에 등록된 옷이 부족합니다. 먼저 옷을 추가해 주세요!');
    }

    final cacheKey = '${clothes.length}_${selectedTpo}_${weather.temperature.round()}';

    // 캐시된 결과가 있고 5분 미만 경과했다면 0초 만에 응답 반환
    if (!forceRefresh &&
        _recommendationCache.containsKey(cacheKey) &&
        _cacheTime.containsKey(cacheKey)) {
      if (DateTime.now().difference(_cacheTime[cacheKey]!) < const Duration(minutes: 5)) {
        return _recommendationCache[cacheKey]!;
      }
    }

    String clothesDescription = clothes
        .map((c) => "- [${c.category}] 이름: ${c.title} (색상: ${c.color})")
        .join("\n");

    String prompt = '''
너는 전문 패션 스타일리스트 AI야. 아래 사용자 옷장 목록과 현재 날씨 정보를 바탕으로 맞춤형 코디 추천 3가지를 생성해줘.

[사용자 옷장 목록]
$clothesDescription

[현재 날씨 환경]
- 기온: ${weather.temperature}°C
- 날씨 상태: ${weather.translatedCondition}

[요청 조건]
- 상황(TPO): $selectedTpo (만약 '전체'라면 캐주얼, 데이트, 비즈니스 등 다양한 스타일로 골고루 섞어줘)
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
          'model': 'openai/gpt-oss-120b',
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

        _recommendationCache[cacheKey] = results;
        _cacheTime[cacheKey] = DateTime.now();

        return results;
      } else {
        if (response.statusCode == 429) {
          throw Exception('AI 사용량 한도가 초과되었습니다. 잠시 후 다시 시도해 주세요.');
        } else if (response.statusCode == 404) {
          throw Exception('AI 모델을 찾을 수 없습니다. (설정 오류)');
        } else {
          throw Exception('AI 서버 오류가 발생했습니다 (코드: ${response.statusCode})');
        }
      }
    } catch (e) {
      debugPrint('AI 추천 에러 발생: $e');
      rethrow;
    }
  }
}
