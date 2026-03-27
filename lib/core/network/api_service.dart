import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';
import '../security/security_layer.dart';

class ApiService {
  late final Dio _groqDio;
  late final Dio _weatherDio;
  final SecurityLayer _security;

  ApiService({required SecurityLayer security}) : _security = security {
    _groqDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${ApiConstants.groqToken}',
      },
    ));

    _weatherDio = Dio(BaseOptions(
      baseUrl: ApiConstants.weatherApiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  // ── Intent ────────────────────────────────────────────────────────────────

  bool _isTaskQuery(String lower) {
    const keywords = [
      'bugun', 'bugün', 'yarin', 'yarın',
      'plan', 'planım', 'planim',
      'gorev', 'görev',
      'program', 'programım', 'programim',
      'sabah', 'aksam', 'akşam', 'ogleden', 'öğleden',
      'hafta', 'ne var', 'ne yapacağım', 'ne yapacagim',
      'randevu', 'toplanti', 'toplantı',
      'bos', 'boş', 'musait', 'müsait',
      'yogun', 'yoğun', 'kac gorev', 'kaç görev',
      'pazartesi', 'sali', 'salı', 'carsamba', 'çarşamba',
      'persembe', 'perşembe', 'cuma', 'cumartesi', 'pazar',
    ];
    return keywords.any((k) => lower.contains(k));
  }

  bool _isWeatherQuery(String lower) {
    const keywords = [
      'hava', 'sicaklik', 'sıcaklık', 'derece',
      'yagmur', 'yağmur', 'kar', 'bulut', 'gunes', 'güneş',
      'dis hava', 'dış hava', 'hava durumu',
    ];
    return keywords.any((k) => lower.contains(k));
  }

  bool _hasNoTasks(String context) {
    if (context.isEmpty) return true;
    return [
      'icin gorev yok', 'için görev yok',
      'gorev yok', 'görev yok',
      'plan yok', 'etkinlik yok',
    ].any((k) => context.contains(k));
  }

  bool _isFreeTimeQuery(String lower) {
    return lower.contains('bos') || lower.contains('boş') ||
        lower.contains('musait') || lower.contains('müsait');
  }

  // ── Context parse ─────────────────────────────────────────────────────────

  // "14:00 esrayi ara" veya "- esrayi ara" → saat cikart
  int? _extractHour(String line) {
    // Parantez icinde saat: "esra ile projeyi bitir (14:30)"
    final parenMatch = RegExp(r'\((\d{1,2})[.:]?(\d{2})\)').firstMatch(line);
    if (parenMatch != null) {
      final h = int.tryParse(parenMatch.group(1)!);
      if (h != null && h != 0) return h;
    }
    // Basta saat: "14.00 esrayi ara" veya "14:30 toplanti"
    final startMatch = RegExp(r'^(\d{1,2})[.:](\d{2})').firstMatch(line.trim());
    if (startMatch != null) {
      final h = int.tryParse(startMatch.group(1)!);
      if (h != null && h != 0) return h;
    }
    // Herhangi bir yerde: HH:MM
    final anyMatch = RegExp(r'(\d{1,2})[.:](\d{2})').firstMatch(line);
    if (anyMatch != null) {
      final h = int.tryParse(anyMatch.group(1)!);
      if (h != null && h != 0) return h;
    }
    // Zaman kelimesi
    if (line.contains('sabah')) return 9;
    if (line.contains('ogleden sonra') || line.contains('öğleden sonra')) return 13;
    if (line.contains('aksam') || line.contains('akşam')) return 19;
    if (line.contains('gece')) return 21;
    return null;
  }

  String _cleanLine(String line) {
    // Sadece (00:00) seklindeki saatsiz gorevleri temizle
    return line
        .replaceAll('(00:00)', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _parseTaskLines(String context) {
    return context
        .split('\n')
        .where((l) => l.trim().startsWith('-'))
        .map((l) => l.trim().replaceFirst('- ', ''))
        .where((l) => l.isNotEmpty)
        .toList();
  }

  // ── Direkt Yanit ──────────────────────────────────────────────────────────

  String _buildDirectResponse(String transcript, String context) {
    final lower = transcript.toLowerCase();
    final lines = _parseTaskLines(context);

    if (lines.isEmpty) {
      if (_isFreeTimeQuery(lower)) {
        return 'Bu zaman diliminde gorev yok, musaitsin.';
      }
      return 'Belirtilen zaman icin herhangi bir planin bulunmuyor.';
    }

    // Bos/musait saat sorgusu
    if (_isFreeTimeQuery(lower)) {
      final busyHours = <int>{};
      for (final line in lines) {
        final h = _extractHour(line);
        if (h != null) busyHours.add(h);
      }
      final freeHours = List.generate(15, (i) => i + 8)
          .where((h) => !busyHours.contains(h))
          .toList();
      if (freeHours.isEmpty) {
        return 'Cok yogun gorunuyorsun, musait saatin yok.';
      }
      final freeStr = freeHours.take(6).map((h) => '$h:00').join(', ');
      return 'Musait saatlerin: $freeStr.';
    }

    // Yogunluk
    if (lower.contains('en yogun') || lower.contains('en yoğun') ||
        lower.contains('kac gorev') || lower.contains('kaç görev')) {
      return 'Bugun ${lines.length} gorev var.';
    }

    // Tek gorev
    if (lines.length == 1) {
      return 'Planin: ${_cleanLine(lines[0])}.';
    }

    // Saate gore sirala
    final sorted = List<String>.from(lines);
    sorted.sort((a, b) {
      final ha = _extractHour(a) ?? 25;
      final hb = _extractHour(b) ?? 25;
      return ha.compareTo(hb);
    });

    final taskList = sorted.map((l) => _cleanLine(l)).join(', ');
    return 'Planların: $taskList.';
  }

  // ── Sehir ─────────────────────────────────────────────────────────────────

  String _extractCity(String lower) {
    const cities = {
      'istanbul': 'Istanbul', 'ankara': 'Ankara', 'izmir': 'Izmir',
      'elazig': 'Elazig', 'elazığ': 'Elazig', 'bursa': 'Bursa',
      'antalya': 'Antalya', 'adana': 'Adana', 'konya': 'Konya',
      'gaziantep': 'Gaziantep', 'mersin': 'Mersin',
      'diyarbakir': 'Diyarbakir', 'kayseri': 'Kayseri',
      'trabzon': 'Trabzon', 'samsun': 'Samsun', 'malatya': 'Malatya',
    };
    for (final entry in cities.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return ApiConstants.defaultCity;
  }

  String _translateWeather(String condition) {
    const map = {
      'clear sky': 'acik ve gunes', 'few clouds': 'az bulutlu',
      'scattered clouds': 'parcali bulutlu', 'broken clouds': 'cok bulutlu',
      'shower rain': 'saganak yagmurlu', 'rain': 'yagmurlu',
      'thunderstorm': 'gokgurututu firtinali', 'snow': 'karli',
      'mist': 'sisli', 'fog': 'yogun sisli', 'haze': 'hafif sisli',
      'drizzle': 'ciselemeli', 'overcast clouds': 'kapali',
      'light rain': 'hafif yagmurlu', 'moderate rain': 'orta siddetli yagmurlu',
      'heavy intensity rain': 'siddetli yagmurlu',
      'light snow': 'hafif karli', 'heavy snow': 'yogun karli',
    };
    final lower = condition.toLowerCase();
    for (final entry in map.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return condition;
  }

  // ── OpenWeatherMap ────────────────────────────────────────────────────────

  Future<String> _callWeather(String city) async {
    print('[AKILLI AYNA] INTENT: HAVA DURUMU → OpenWeatherMap | Sehir: $city');
    try {
      final response = await _weatherDio.get('', queryParameters: {
        'q': city,
        'appid': ApiConstants.weatherToken,
        'units': 'metric',
        'lang': 'tr',
      });
      if (response.statusCode == 200) {
        final data = response.data;
        final temp = (data['main']['temp'] as num).round();
        final feelsLike = (data['main']['feels_like'] as num).round();
        final humidity = data['main']['humidity'];
        final desc = _translateWeather(data['weather'][0]['description'] as String);
        final cityName = data['name'] as String;
        final windSpeed = (data['wind']['speed'] as num).toStringAsFixed(1);
        final reply = '$cityName\'da hava $desc. Sicaklik $temp derece, '
            'hissedilen $feelsLike derece. Nem yuzde $humidity, '
            'ruzgar saatte $windSpeed metre.';
        print('[AKILLI AYNA] YANIT (OpenWeatherMap): $reply');
        return reply;
      }
      return 'Hava durumu bilgisi alinamadi.';
    } on DioException catch (e) {
      print('[AKILLI AYNA] HATA: OpenWeatherMap - ${e.message}');
      if (e.response?.statusCode == 404) return 'Bu sehir bulunamadi.';
      return 'Hava durumu servisi su an erisilebilir degil.';
    } catch (_) {
      return 'Hava durumu alinamadi.';
    }
  }

  // ── Groq ──────────────────────────────────────────────────────────────────

  Future<String> _callGroq(String message, List<Map<String, String>> history) async {
    print('[AKILLI AYNA] INTENT: SOHBET → Groq Llama 3.1 8B');
    print('[AKILLI AYNA] SORU: $message');
    try {
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content': 'Sen Turkce konusan, samimi ve yardimci bir akilli ayna '
              'asistanisin. Kisa ve dogal cevaplar ver.',
        },
      ];
      final recent = history.length > 6
          ? history.sublist(history.length - 6)
          : history;
      for (final msg in recent) {
        messages.add({'role': msg['role']!, 'content': msg['content']!});
      }
      messages.add({'role': 'user', 'content': message});

      final response = await _groqDio.post(
        ApiConstants.groqApiUrl,
        data: jsonEncode({
          'model': ApiConstants.groqModel,
          'messages': messages,
          'max_tokens': 200,
          'temperature': 0.7,
        }),
      );
      if (response.statusCode == 200) {
        final reply = response.data['choices'][0]['message']['content'] as String;
        print('[AKILLI AYNA] YANIT (Groq): $reply');
        return reply;
      }
      throw ServerException(message: 'Groq hatasi', statusCode: response.statusCode);
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Groq baglanti hatasi');
    }
  }

  // ── Ana Fonksiyon ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendVoiceCommand(
    String transcript, {
    String context = '',
    List<Map<String, String>> history = const [],
  }) async {
    await _security.requireConsent();
    final lower = transcript.toLowerCase().trim();
    print('[AKILLI AYNA] ══════════════════════════════════');
    print('[AKILLI AYNA] GELEN SORU: $transcript');
    print('[AKILLI AYNA] CONTEXT: ${context.isEmpty ? "(bos)" : context}');

    // 1. Hava durumu
    if (_isWeatherQuery(lower)) {
      final reply = await _callWeather(_extractCity(lower));
      print('[AKILLI AYNA] ══════════════════════════════════');
      return {'response': reply};
    }

    // 2. Gorev sorgulama
    if (_isTaskQuery(lower)) {
      print('[AKILLI AYNA] INTENT: GOREV → Direkt Metin');
      if (_hasNoTasks(context)) {
        // Bos saat soruyorsa ayri mesaj
        final reply = _isFreeTimeQuery(lower)
            ? 'Bu zaman diliminde gorev yok, musaitsin.'
            : 'Belirtilen zaman icin herhangi bir planin bulunmuyor.';
        print('[AKILLI AYNA] YANIT (bos): $reply');
        print('[AKILLI AYNA] ══════════════════════════════════');
        return {'response': reply};
      }
      final reply = _buildDirectResponse(transcript, context);
      print('[AKILLI AYNA] YANIT (direkt): $reply');
      print('[AKILLI AYNA] ══════════════════════════════════');
      return {'response': reply};
    }

    // 3. Sohbet → Groq
    final reply = await _callGroq(transcript, history);
    print('[AKILLI AYNA] ══════════════════════════════════');
    return {'response': reply};
  }

  Future<Map<String, dynamic>> inferAi(String prompt, {String context = ''}) async {
    await _security.requireConsent();
    if (!_hasNoTasks(context)) {
      return {'generated_text': _buildDirectResponse(prompt, context)};
    }
    return {'generated_text': 'Belirtilen zaman icin plan bulunmuyor.'};
  }

  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, dynamic>? queryParams}) async {
    await _security.requireConsent();
    try {
      return _handleResponse(
          await _groqDio.get(endpoint, queryParameters: queryParams));
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> post(String endpoint,
      {required Map<String, dynamic> body}) async {
    await _security.requireConsent();
    try {
      return _handleResponse(await _groqDio.post(endpoint, data: body));
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> put(String endpoint,
      {required Map<String, dynamic> body}) async {
    await _security.requireConsent();
    try {
      return _handleResponse(await _groqDio.put(endpoint, data: body));
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> delete(String endpoint) async {
    await _security.requireConsent();
    try {
      await _groqDio.delete(endpoint);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Map<String, dynamic> _handleResponse(Response response) {
    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      return (response.data as Map<String, dynamic>?) ?? {};
    }
    throw ServerException(
        message: response.statusMessage ?? 'Sunucu hatasi',
        statusCode: statusCode);
  }

  Exception _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const NetworkException('Baglanti zaman asimina ugradi.');
      case DioExceptionType.connectionError:
        return const NetworkException('Sunucuya ulasilamiyor.');
      case DioExceptionType.badResponse:
        return ServerException(
            message: e.response?.statusMessage ?? 'Sunucu hatasi',
            statusCode: e.response?.statusCode);
      default:
        return NetworkException(e.message ?? 'Bilinmeyen ag hatasi.');
    }
  }
}
