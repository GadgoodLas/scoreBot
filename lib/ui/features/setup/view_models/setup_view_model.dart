import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/data/repositories/match_repository.dart';
import 'package:score_bot/data/services/tts_service.dart';
import 'package:score_bot/data/services/lineup_parser.dart';

/// ViewModel de l'écran de configuration du match.
class SetupViewModel extends ChangeNotifier {
  SetupViewModel({
    required MatchRepository matchRepository,
    TtsService? ttsService,
  }) : _repository = matchRepository,
       _ttsService = ttsService {
    _ttsService?.setCompletionHandler(() {
      if (_isAnnouncingLineup) {
        _isAnnouncingLineup = false;
        notifyListeners();
      }
    });
  }

  final MatchRepository _repository;
  final TtsService? _ttsService;
  final _uuid = const Uuid();

  // ─────────────── État ───────────────

  SportType _selectedSport = SportType.football;
  SportType get selectedSport => _selectedSport;

  String _teamAName = 'Team A';
  String get teamAName => _teamAName;

  String _teamBName = 'Team B';
  String get teamBName => _teamBName;

  String _teamAColor = 'rouge';
  String get teamAColor => _teamAColor;

  String _teamBColor = 'bleu';
  String get teamBColor => _teamBColor;

  final List<Player> _teamAPlayers = [];
  List<Player> get teamAPlayers => List.unmodifiable(_teamAPlayers);

  final List<Player> _teamBPlayers = [];
  List<Player> get teamBPlayers => List.unmodifiable(_teamBPlayers);

  int _durationMinutes = 90;
  int get durationMinutes => _durationMinutes;

  int? _breakDurationMinutes = 45;
  int? get breakDurationMinutes => _breakDurationMinutes;

  bool _isCreating = false;
  bool get isCreating => _isCreating;

  bool _isAnnouncingLineup = false;
  bool get isAnnouncingLineup => _isAnnouncingLineup;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─────────────── Configuration IA & Mode Vocal ───────────────

  bool get shouldPromptAiOnboarding =>
      !_repository.hasSeenAiOnboarding && !_repository.isAiConfigured;

  bool get isAiConfigured => _repository.isAiConfigured;

  String get currentAiModel => _repository.aiModel;

  String get currentApiKey => _repository.apiKey;

  String get voiceEngine => _repository.voiceEngine;

  bool get isLocalVoiceMode => _repository.isLocalVoiceMode;

  String get languageCode => _repository.languageCode;

  Future<void> setLanguageCode(String code) async {
    await _repository.setLanguageCode(code);
    notifyListeners();
  }

  Future<void> setVoiceEngine(String engine) async {
    await _repository.setVoiceEngine(engine);
    notifyListeners();
  }

  Future<void> saveAiConfig({
    required String apiKey,
    required String model,
    String? voiceEngine,
  }) async {
    await _repository.saveAiConfig(
      apiKey: apiKey,
      model: model,
      voiceEngine: voiceEngine,
    );
    notifyListeners();
  }

  Future<void> dismissAiOnboarding() async {
    await _repository.dismissAiOnboarding();
    notifyListeners();
  }

  Future<bool> testAiConnection({
    required String apiKey,
    required String model,
  }) {
    return _repository.testAiConnection(apiKey: apiKey, model: model);
  }

  // ─────────────── Actions ───────────────

  void selectSport(SportType sport) {
    _selectedSport = sport;
    _durationMinutes =
        sport.matchDurationMinutes > 0 ? sport.matchDurationMinutes : 90;
    _breakDurationMinutes =
        sport.hasHalftime && _durationMinutes > 0
            ? (_durationMinutes / 2).round()
            : null;
    notifyListeners();
  }

  void setTeamAName(String name) {
    _teamAName = name;
    notifyListeners();
  }

  void setTeamBName(String name) {
    _teamBName = name;
    notifyListeners();
  }

  void setTeamAColor(String color) {
    _teamAColor = color;
    notifyListeners();
  }

  void setTeamBColor(String color) {
    _teamBColor = color;
    notifyListeners();
  }

  void addPlayerToTeamA(String input) {
    final parsed = LineupParser.parse(input);
    for (final p in parsed) {
      if (!_teamAPlayers.any(
        (existing) => existing.name.toLowerCase() == p.name.toLowerCase(),
      )) {
        _teamAPlayers.add(p);
      }
    }
    notifyListeners();
  }

  void addCustomPlayerToTeamA({required String name, int? number}) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (!_teamAPlayers.any(
      (existing) => existing.name.toLowerCase() == clean.toLowerCase(),
    )) {
      _teamAPlayers.add(Player(id: _uuid.v4(), name: clean, number: number));
      notifyListeners();
    }
  }

  void removePlayerFromTeamA(int index) {
    if (index >= 0 && index < _teamAPlayers.length) {
      _teamAPlayers.removeAt(index);
      notifyListeners();
    }
  }

  void clearTeamAPlayers() {
    _teamAPlayers.clear();
    notifyListeners();
  }

  void setTeamAPlayers(List<Player> players) {
    _teamAPlayers.clear();
    _teamAPlayers.addAll(players);
    notifyListeners();
  }

  void addPlayerToTeamB(String input) {
    final parsed = LineupParser.parse(input);
    for (final p in parsed) {
      if (!_teamBPlayers.any(
        (existing) => existing.name.toLowerCase() == p.name.toLowerCase(),
      )) {
        _teamBPlayers.add(p);
      }
    }
    notifyListeners();
  }

  void addCustomPlayerToTeamB({required String name, int? number}) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (!_teamBPlayers.any(
      (existing) => existing.name.toLowerCase() == clean.toLowerCase(),
    )) {
      _teamBPlayers.add(Player(id: _uuid.v4(), name: clean, number: number));
      notifyListeners();
    }
  }

  void removePlayerFromTeamB(int index) {
    if (index >= 0 && index < _teamBPlayers.length) {
      _teamBPlayers.removeAt(index);
      notifyListeners();
    }
  }

  void clearTeamBPlayers() {
    _teamBPlayers.clear();
    notifyListeners();
  }

  void setTeamBPlayers(List<Player> players) {
    _teamBPlayers.clear();
    _teamBPlayers.addAll(players);
    notifyListeners();
  }

  /// Démarre l'écoute vocale pour la dictée de composition d'équipe.
  Future<void> startLineupDictation({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    await _repository.startLineupDictation(onResult: onResult);
  }

  /// Arrête l'écoute vocale de composition.
  Future<void> stopLineupDictation() async {
    await _repository.stopLineupDictation();
  }

  void setDuration(int minutes) {
    _durationMinutes = minutes;
    if (_breakDurationMinutes != null &&
        _breakDurationMinutes! >= _durationMinutes) {
      _breakDurationMinutes = (_durationMinutes / 2).round();
    }
    notifyListeners();
  }

  void setBreakDuration(int? minutes) {
    _breakDurationMinutes = minutes;
    notifyListeners();
  }

  /// Valide la configuration et retourne le message d'erreur, ou null si OK.
  String? validate() {
    if (_teamAName.trim().isEmpty) {
      return 'Le nom de l\'équipe A est requis';
    }
    if (_teamBName.trim().isEmpty) {
      return 'Le nom de l\'équipe B est requis';
    }
    if (_teamAName.trim().toLowerCase() == _teamBName.trim().toLowerCase()) {
      return 'Les deux équipes doivent avoir des noms différents';
    }
    if (_durationMinutes <= 0) {
      return 'La durée doit être positive';
    }
    return null;
  }

  /// Génère le texte d'annonce vocale des compositions.
  String generateLineupAnnouncement({
    required String sportLabel,
    required String languageCode,
  }) {
    final nameA = _teamAName.trim().isEmpty ? 'Équipe A' : _teamAName.trim();
    final nameB = _teamBName.trim().isEmpty ? 'Équipe B' : _teamBName.trim();
    final isFr = languageCode.toLowerCase().startsWith('fr');

    if (isFr) {
      final buffer = StringBuffer('Match de $sportLabel. ');
      buffer.write('$nameA contre $nameB. ');
      if (_teamAPlayers.isNotEmpty) {
        final lineupA = _teamAPlayers.map((p) => p.shortLabel).join(', ');
        buffer.write('Composition de $nameA : $lineupA. ');
      }
      if (_teamBPlayers.isNotEmpty) {
        final lineupB = _teamBPlayers.map((p) => p.shortLabel).join(', ');
        buffer.write('Composition de $nameB : $lineupB. ');
      }
      buffer.write('Bon match à tous !');
      return buffer.toString();
    } else {
      final buffer = StringBuffer('$sportLabel match. ');
      buffer.write('$nameA versus $nameB. ');
      if (_teamAPlayers.isNotEmpty) {
        final lineupA = _teamAPlayers.map((p) => p.shortLabel).join(', ');
        buffer.write('Team $nameA lineup: $lineupA. ');
      }
      if (_teamBPlayers.isNotEmpty) {
        final lineupB = _teamBPlayers.map((p) => p.shortLabel).join(', ');
        buffer.write('Team $nameB lineup: $lineupB. ');
      }
      buffer.write('Good luck everyone!');
      return buffer.toString();
    }
  }

  /// Active ou interrompt l'annonce vocale des compositions.
  Future<void> toggleLineupAnnouncement({
    required String sportLabel,
    required String languageCode,
  }) async {
    if (_isAnnouncingLineup) {
      await stopLineupAnnouncement();
      return;
    }

    final text = generateLineupAnnouncement(
      sportLabel: sportLabel,
      languageCode: languageCode,
    );

    _isAnnouncingLineup = true;
    notifyListeners();

    if (_ttsService != null) {
      await _ttsService.setLanguage(languageCode);
      await _ttsService.speak(text);
    }
  }

  /// Arrête la lecture vocale des compositions si elle est en cours.
  Future<void> stopLineupAnnouncement() async {
    if (!_isAnnouncingLineup) return;
    _isAnnouncingLineup = false;
    notifyListeners();
    await _ttsService?.stop();
  }

  /// Crée le match et retourne l'objet [GameMatch] ou null si erreur.
  Future<GameMatch?> startMatch() async {
    await stopLineupAnnouncement();
    final error = validate();
    if (error != null) {
      _errorMessage = error;
      notifyListeners();
      return null;
    }

    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final teamA = Team(
        id: _uuid.v4(),
        name: _teamAName.trim(),
        color: _teamAColor.trim(),
        players: _teamAPlayers,
      );
      final teamB = Team(
        id: _uuid.v4(),
        name: _teamBName.trim(),
        color: _teamBColor.trim(),
        players: _teamBPlayers,
      );

      final match = await _repository.createMatch(
        sport: _selectedSport,
        teamA: teamA,
        teamB: teamB,
        durationMinutes: _durationMinutes,
        breakDurationMinutes: _breakDurationMinutes,
      );

      return match;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création du match : $e';
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopLineupAnnouncement();
    super.dispose();
  }
}
