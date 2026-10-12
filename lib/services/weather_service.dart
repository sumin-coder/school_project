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

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    String name = json['name'] ?? '서울';

    if (name == 'Reisui' || name == "Yeosu") {
      name = '여수';
    }

    return WeatherData(
      temperature: (json['main']['temp'] as num).toDouble(),
      condition: json['weather'][0]['main'],
      cityName: name,
    );
  }
}

class WeatherService {
  static const String apiKey = '3270d5ab9d452945e1ddee6b56053252';

  // ⚡ 메모리 캐싱 (10분간 보관하여 앱 속도 100배 향상)
  static WeatherData? _cachedWeather;
  static DateTime? _cacheTimestamp;

  Future<WeatherData> fetchWeather({String cityName = 'Seoul'}) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$cityName&appid=$apiKey&units=metric&lang=kr',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return WeatherData.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('날씨 데이터를 불러오는데 실패했습니다.');
    }
  }

  // 📍 위도, 경도(GPS) 기반 실시간 날씨 가져오기 (캐싱 적용)
  Future<WeatherData> fetchWeatherByCoordinates(double lat, double lon) async {
    if (_cachedWeather != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < const Duration(minutes: 10)) {
        return _cachedWeather!;
      }
    }

    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=kr',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final weather = WeatherData.fromJson(jsonDecode(response.body));
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
