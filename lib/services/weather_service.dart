import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final String condition;
  final String cityName;

  WeatherData({
    required this.temperature,
    required this.condition,
    required this.cityName,
  });

  String get translatedCondition {
    switch (condition.toLowerCase()) {
      case 'clear':
        return '맑음';
      case 'rain':
        return '비';
      case 'clouds':
      case 'cloudy':
        return '구름 많음';
      case 'snow':
        return '눈';
      case 'thunderstorm':
        return '천둥번개';
      case 'drizzle':
        return '이슬비';
      case 'mist':
      case 'fog':
        return '안개';
      default:
        return condition;
    }
  }

  factory WeatherData.fromOpenMeteo(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final code = (current['weather_code'] as num).toInt();
    final condition = switch (code) {
      0 => 'Clear',
      1 || 2 || 3 => 'Clouds',
      45 || 48 => 'Fog',
      51 || 53 || 55 || 56 || 57 => 'Drizzle',
      61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => 'Rain',
      71 || 73 || 75 || 77 || 85 || 86 => 'Snow',
      95 || 96 || 99 => 'Thunderstorm',
      _ => 'Clouds',
    };
    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      condition: condition,
      cityName: '현재 위치',
    );
  }
}

class WeatherService {
  // ⚡ 메모리 캐싱 (10분간 보관하여 앱 속도 100배 향상)
  static WeatherData? _cachedWeather;
  static DateTime? _cacheTimestamp;

  Future<WeatherData> fetchWeather({String cityName = 'Seoul'}) async {
    final url = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {'name': cityName, 'count': '1', 'language': 'ko', 'format': 'json'},
    );
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('날씨 위치 정보를 불러오지 못했습니다.');
    }
    final locations = jsonDecode(response.body)['results'] as List?;
    if (locations == null || locations.isEmpty) {
      throw Exception('날씨 위치를 찾지 못했습니다.');
    }
    final location = locations.first as Map<String, dynamic>;
    return fetchWeatherByCoordinates(
      (location['latitude'] as num).toDouble(),
      (location['longitude'] as num).toDouble(),
    );
  }

  // 📍 위도, 경도(GPS) 기반 실시간 날씨 가져오기 (캐싱 적용)
  Future<WeatherData> fetchWeatherByCoordinates(double lat, double lon) async {
    if (_cachedWeather != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < const Duration(minutes: 10)) {
        return _cachedWeather!;
      }
    }

    final url = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': '$lat',
        'longitude': '$lon',
        'current': 'temperature_2m,weather_code',
        'timezone': 'auto',
      },
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final weather = WeatherData.fromOpenMeteo(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        _cachedWeather = weather;
        _cacheTimestamp = DateTime.now();
        return weather;
      } else {
        if (_cachedWeather != null) return _cachedWeather!;
        throw Exception('위치 기반 날씨 데이터를 불러오는데 실패했습니다.');
      }
    } catch (e) {
      if (_cachedWeather != null) return _cachedWeather!;
      rethrow;
    }
  }
}
