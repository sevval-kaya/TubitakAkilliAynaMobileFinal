/// HuggingFace Dedicated Endpoint, Groq API ve OpenWeatherMap sabitleri.
class ApiConstants {
  ApiConstants._();

  // ── HuggingFace Dedicated Endpoint ───────────────────────────────────────
  static const String hfEndpointUrl = String.fromEnvironment(
    'HF_ENDPOINT_URL',
    defaultValue: 'https://YOUR_ENDPOINT.us-east-1.aws.endpoints.huggingface.cloud',
  );
  static const String hfToken = String.fromEnvironment(
    'HF_TOKEN',
    defaultValue: '',
  );

  // ── Groq API ──────────────────────────────────────────────────────────────
  static const String groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String groqToken = String.fromEnvironment(
    'GROQ_TOKEN',
    defaultValue: '',
  );
  static const String groqModel = 'llama-3.1-8b-instant';

  // ── OpenWeatherMap API ────────────────────────────────────────────────────
  static const String weatherApiUrl = 'https://api.openweathermap.org/data/2.5/weather';
  static const String weatherToken = String.fromEnvironment(
    'WEATHER_TOKEN',
    defaultValue: '',
  );
  static const String defaultCity = 'Elazig';

  // ── Base URL ──────────────────────────────────────────────────────────────
  static String get baseUrl => hfEndpointUrl;

  // ── Endpoint'ler ──────────────────────────────────────────────────────────
  static const String aiInferenceEndpoint = '/';
  static const String aiStatusEndpoint = '/';
  static const String voiceCommandEndpoint = '/';
  static const String userSyncEndpoint = '/';

  // ── Timeout ───────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 120);
  static const Duration sendTimeout = Duration(seconds: 60);

  // ── HTTP Headers ──────────────────────────────────────────────────────────
  static const String headerContentType = 'application/json';
  static const String headerAccept = 'application/json';
  static const String headerAuthorization = 'Authorization';
  static const String headerDeviceId = 'X-Device-ID';
  static const String headerApiVersion = 'X-API-Version';
  static const String apiVersion = 'v1';
}
