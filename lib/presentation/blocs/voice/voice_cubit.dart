import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../data/datasources/remote/ai_remote_datasource.dart';
import '../task/task_bloc.dart';
import '../../../domain/entities/task.dart';

// ── State ──────────────────────────────────────────────────────────────────

abstract class VoiceState extends Equatable {
  const VoiceState();
  @override
  List<Object?> get props => [];
}

class VoiceIdle extends VoiceState {
  const VoiceIdle();
}

class VoiceInitializing extends VoiceState {
  const VoiceInitializing();
}

class VoiceListening extends VoiceState {
  final String partialTranscript;
  const VoiceListening({this.partialTranscript = ''});
  @override
  List<Object?> get props => [partialTranscript];
}

class VoiceProcessing extends VoiceState {
  final String transcript;
  const VoiceProcessing({required this.transcript});
  @override
  List<Object?> get props => [transcript];
}

class VoiceSpeaking extends VoiceState {
  final String response;
  const VoiceSpeaking({required this.response});
  @override
  List<Object?> get props => [response];
}

class VoiceError extends VoiceState {
  final Failure failure;
  const VoiceError(this.failure);
  @override
  List<Object?> get props => [failure];
}

// ── Cubit ──────────────────────────────────────────────────────────────────

/// Ses tanıma → AI işleme → TTS konuşma akışını yöneten Cubit.
///
/// Akış:
///   [Mikrofon] → speech_to_text → transcript → ApiService (NGINX)
///   → AI yanıtı → flutter_tts → [Hoparlör]
class VoiceCubit extends Cubit<VoiceState> {
  final stt.SpeechToText _speechToText;
  final FlutterTts _tts;
  final IAiRemoteDataSource _aiDataSource;
  final TaskBloc _taskBloc;

  bool _isInitialized = false;

  // Son 5 tur konuşma geçmişi (10 mesaj)
  final List<Map<String, String>> _history = [];

  VoiceCubit({
    required stt.SpeechToText speechToText,
    required FlutterTts tts,
    required IAiRemoteDataSource aiDataSource,
    required TaskBloc taskBloc,
  })  : _speechToText = speechToText,
        _tts = tts,
        _aiDataSource = aiDataSource,
        _taskBloc = taskBloc,
        super(const VoiceIdle()) {
    _configureTts();
  }

  // ── TTS Yapılandırması ────────────────────────────────────────────────────

  void _configureTts() {
    _tts.setLanguage('tr-TR');
    _tts.setSpeechRate(1.0);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      if (!isClosed) emit(const VoiceIdle());
    });
  }

  void updateTtsSettings({double? speed, double? pitch}) {
    if (speed != null) _tts.setSpeechRate(speed);
    if (pitch != null) _tts.setPitch(pitch);
  }

  // ── Başlat / Durdur ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    emit(const VoiceInitializing());
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          if (!isClosed) emit(VoiceError(VoiceFailure(error.errorMsg)));
        },
        onStatus: (status) {
          // dinleme durumu izleme
        },
      );
      if (_isInitialized) {
        emit(const VoiceIdle());
      } else {
        emit(const VoiceError(VoiceFailure('Mikrofon başlatılamadı.')));
      }
    } catch (e) {
      emit(const VoiceError(PermissionFailure()));
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return;

    emit(const VoiceListening());

    // speech_to_text v7 — SpeechListenOptions kullanılır
    await _speechToText.listen(
      localeId: 'tr_TR',
      listenFor: AppConstants.voiceListenTimeout,
      pauseFor: AppConstants.voicePauseThreshold,
      onResult: (result) {
        if (!isClosed) {
          if (result.finalResult) {
            _processTranscript(result.recognizedWords);
          } else {
            emit(VoiceListening(partialTranscript: result.recognizedWords));
          }
        }
      },
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    if (!isClosed) emit(const VoiceIdle());
  }

  // ── AI İşleme ─────────────────────────────────────────────────────────────

  String _buildTaskContext({String transcript = ''}) {
    final state = _taskBloc.state;
    if (state is! TaskLoaded || state.tasks.isEmpty) return '';

    final today = DateTime.now();
    final lower = transcript.toLowerCase();

    // ── Gün tespiti ───────────────────────────────────────────────────────
    DateTime targetDate;
    String dateLabel;

    if (lower.contains('yarın')) {
      targetDate = today.add(const Duration(days: 1));
      dateLabel = 'Yarın (${_formatDate(targetDate)})';
    } else if (lower.contains('bu hafta') || lower.contains('hafta')) {
      return _buildWeekContext(state.tasks, today);
    } else {
      final dateMatch = RegExp(r'(\d{1,2})\s*mart').firstMatch(lower);
      if (dateMatch != null) {
        final day = int.tryParse(dateMatch.group(1)!);
        if (day != null) {
          targetDate = DateTime(today.year, 3, day);
          dateLabel = '$day Mart';
        } else {
          targetDate = today;
          dateLabel = 'Bugün (${_formatDate(today)})';
        }
      } else {
        targetDate = today;
        dateLabel = 'Bugün (${_formatDate(today)})';
      }
    }

    // ── Zaman dilimi tespiti ──────────────────────────────────────────────
    int? filterStart;
    int? filterEnd;
    String? timeLabel;

    // Zaman dilimi kurallari:
    // Sabah      : 05:00 - 17:00
    // Ogleden once: 00:00 - 12:00
    // Oglen       : 11:00 - 13:00
    // Ogleden sonra: 12:00 - 23:59
    // Aksam (gece): 17:01 - 04:59 (= 17-24 + 0-5)
    // Gece        : 17:01 - 04:59

    if (lower.contains('öğleden önce') || lower.contains('ogleden once')) {
      filterStart = 0; filterEnd = 12; timeLabel = 'öğleden önce';
    } else if (lower.contains('öğleden sonra') || lower.contains('ogleden sonra')) {
      filterStart = 12; filterEnd = 24; timeLabel = 'öğleden sonra';
    } else if (lower.contains('öğle') || lower.contains('ogle')) {
      filterStart = 11; filterEnd = 13; timeLabel = 'öğle';
    } else if (lower.contains('sabah')) {
      filterStart = 5; filterEnd = 17; timeLabel = 'sabah';
    } else if (lower.contains('akşam') || lower.contains('aksam') ||
               lower.contains('gece')) {
      // 17:01-23:59 ve 00:00-04:59
      filterStart = -1; filterEnd = -1; timeLabel = lower.contains('gece') ? 'gece' : 'akşam';
    }

    final specificTime = RegExp(r'saat\s*(\d{1,2})(?::(\d{2}))?').firstMatch(lower);
    if (specificTime != null) {
      final h = int.tryParse(specificTime.group(1)!);
      if (h != null) {
        filterStart = h; filterEnd = h + 1; timeLabel = 'saat $h:00';
      }
    }

    // ── Görevleri filtrele ────────────────────────────────────────────────
    final tasks = state.tasks.where((t) {
      if (t.isCompleted || t.dueDate == null) return false;
      final d = t.dueDate!;
      if (d.year != targetDate.year || d.month != targetDate.month || d.day != targetDate.day) return false;
      if (filterStart == -1 && filterEnd == -1) {
        // Aksam/gece: 17:00-23:59 veya 00:00-04:59
        return d.hour >= 17 || d.hour < 5;
      }
      if (filterStart != null && filterEnd != null) {
        return d.hour >= filterStart! && d.hour < filterEnd!;
      }
      return true;
    }).toList();

    final fullLabel = timeLabel != null ? '$dateLabel $timeLabel' : dateLabel;
    if (tasks.isEmpty) return '$fullLabel için görev yok.';

    final lines = tasks.map((t) {
      final time =
          '${t.dueDate!.hour.toString().padLeft(2, '0')}:${t.dueDate!.minute.toString().padLeft(2, '0')}';
      return '- ${t.title} ($time)';
    }).join('\n');

    return '$fullLabel görevleri:\n$lines';
  }

  String _buildWeekContext(List<dynamic> tasks, DateTime today) {
    final weekEnd = today.add(const Duration(days: 7));
    final Map<String, List<String>> byDay = {};

    for (final t in tasks) {
      if (t.isCompleted || t.dueDate == null) continue;
      final d = t.dueDate!;
      if (d.isBefore(DateTime(today.year, today.month, today.day)) ||
          d.isAfter(weekEnd)) continue;
      final key = _formatDate(d);
      final time =
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add('${t.title} ($time)');
    }

    if (byDay.isEmpty) return 'Bu hafta görev yok.';
    final lines =
        byDay.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join('\n');
    return 'Bugün: ${_formatDate(today)}\nBu haftaki görevler:\n$lines';
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} Mart';

  Future<void> _processTranscript(String transcript) async {
    if (transcript.trim().isEmpty) {
      emit(const VoiceIdle());
      return;
    }

    emit(VoiceProcessing(transcript: transcript));

    // Önce yerel görev ekleme niyeti var mı kontrol et
    final addedTask = await _tryAddTaskFromVoice(transcript);
    if (addedTask != null) {
      await _speak(addedTask);
      return;
    }

    final context = _buildTaskContext(transcript: transcript);

    try {
      final response = await _aiDataSource.processVoiceCommand(
        transcript,
        context: context,
        history: List.from(_history),
      );

      // Geçmişe ekle (en fazla 10 mesaj = 5 tur)
      _history.add({'role': 'user', 'content': transcript});
      _history.add({'role': 'assistant', 'content': response});
      if (_history.length > 10) {
        _history.removeRange(0, _history.length - 10);
      }

      await _speak(response);
    } on Exception {
      await _speak(_buildOfflineResponse(transcript));
    }
  }

  // ── Sesle Görev Ekleme ────────────────────────────────────────────────────

  bool _isAddTaskIntent(String lower) {
    return lower.contains('görev ekle') ||
        lower.contains('yeni görev') ||
        lower.contains('görev oluştur') ||
        lower.contains('hatırlat') ||
        lower.contains('listeye ekle') ||
        lower.contains('not al');
  }

  Future<String?> _tryAddTaskFromVoice(String transcript) async {
    final lower = transcript.toLowerCase();
    if (!_isAddTaskIntent(lower)) return null;

    String title = transcript;
    for (final trigger in [
      'görev ekle',
      'yeni görev:',
      'yeni görev',
      'görev oluştur',
      'hatırlat',
      'listeye ekle',
      'not al',
    ]) {
      final idx = lower.indexOf(trigger);
      if (idx != -1) {
        title = transcript.substring(idx + trigger.length).trim();
        break;
      }
    }

    if (title.isEmpty) return null;

    // ── Saat algıla ───────────────────────────────────────────────────────
    DateTime? dueDate;
    final now = DateTime.now();

    // "saat 14:30" veya "saat 3"
    final timeRegex = RegExp(r'saat\s*(\d{1,2})(?::(\d{2}))?');
    final timeMatch = timeRegex.firstMatch(lower);
    if (timeMatch != null) {
      final hour = int.tryParse(timeMatch.group(1)!);
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      if (hour != null && hour >= 0 && hour <= 23) {
        dueDate = DateTime(now.year, now.month, now.day, hour, minute);
      }
      title = title.replaceAll(timeRegex, '').trim();
    }

    // "sabah" → 09:00, "öğle" → 12:00, "akşam" → 19:00, "gece" → 21:00
    if (dueDate == null) {
      if (lower.contains('sabah')) {
        dueDate = DateTime(now.year, now.month, now.day, 9, 0);
        title = title.replaceAll(RegExp(r'sabah'), '').trim();
      } else if (lower.contains('öğle') || lower.contains('ogle')) {
        dueDate = DateTime(now.year, now.month, now.day, 12, 0);
        title = title.replaceAll(RegExp(r'öğle|ogle'), '').trim();
      } else if (lower.contains('akşam') || lower.contains('aksam')) {
        dueDate = DateTime(now.year, now.month, now.day, 19, 0);
        title = title.replaceAll(RegExp(r'akşam|aksam'), '').trim();
      } else if (lower.contains('gece')) {
        dueDate = DateTime(now.year, now.month, now.day, 21, 0);
        title = title.replaceAll(RegExp(r'gece'), '').trim();
      }
    }

    // "yarın" → yarına ekle
    if (lower.contains('yarın') || lower.contains('yarin')) {
      final tomorrow = now.add(const Duration(days: 1));
      final hour = dueDate?.hour ?? 9;
      final minute = dueDate?.minute ?? 0;
      dueDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
      title = title.replaceAll(RegExp(r'yarın|yarin'), '').trim();
    }

    // "X mart" → o güne ekle
    final dateMatch = RegExp(r'(\d{1,2})\s*mart').firstMatch(lower);
    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1)!);
      if (day != null) {
        final hour = dueDate?.hour ?? 9;
        final minute = dueDate?.minute ?? 0;
        dueDate = DateTime(now.year, 3, day, hour, minute);
        title = title.replaceAll(dateMatch.group(0)!, '').trim();
      }
    }

    // Birden fazla boşluğu temizle
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) return null;

    // Aktif kullanıcı ID'sini task state'den al
    final taskState = _taskBloc.state;
    String userId = '';
    if (taskState is TaskLoaded && taskState.tasks.isNotEmpty) {
      userId = taskState.tasks.first.userId;
    }
    if (userId.isEmpty) return null;

    final task = Task(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      description: 'Sesle eklendi',
      priority: TaskPriority.medium,
      category: TaskCategory.personal,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );

    _taskBloc.add(AddTaskEvent(task));

    // Onay mesajı
    final timeStr = dueDate != null
        ? ' saat ${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')} için'
        : '';
    return '"$title"$timeStr göreve eklendi.';
  }

  Future<void> _speak(String text) async {
    emit(VoiceSpeaking(response: text));
    await _tts.speak(text);
  }

  /// Bağlantısız (offline) mod için basit kural tabanlı yanıtlar.
  String _buildOfflineResponse(String transcript) {
    final lower = transcript.toLowerCase();
    if (lower.contains('merhaba') || lower.contains('selam')) {
      return 'Merhaba! Size nasıl yardımcı olabilirim?';
    }
    if (lower.contains('görev') || lower.contains('yapılacak')) {
      return 'Görev listenize bakabilirsiniz.';
    }
    if (lower.contains('saat') || lower.contains('zaman')) {
      final now = DateTime.now();
      return 'Saat ${now.hour}:${now.minute.toString().padLeft(2, '0')}.';
    }
    return 'Üzgünüm, şu an internet bağlantım yok. Lütfen tekrar deneyin.';
  }

  Future<void> speak(String text) async => _speak(text);

  Future<void> stopSpeaking() async {
    await _tts.stop();
    if (!isClosed) emit(const VoiceIdle());
  }

  @override
  Future<void> close() async {
    await _speechToText.cancel();
    await _tts.stop();
    return super.close();
  }
}
