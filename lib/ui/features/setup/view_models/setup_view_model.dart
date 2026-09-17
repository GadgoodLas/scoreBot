import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:score_bot/domain/models/match.dart';
import 'package:score_bot/domain/models/sport_type.dart';
import 'package:score_bot/data/repositories/match_repository.dart';

/// ViewModel de l'écran de configuration du match.
class SetupViewModel extends ChangeNotifier {
  SetupViewModel({required MatchRepository matchRepository})
      : _repository = matchRepository;

  final MatchRepository _repository;
  final _uuid = const Uuid();

  // ─────────────── État ───────────────

  SportType _selectedSport = SportType.football;
  SportType get selectedSport => _selectedSport;

  String _teamAName = 'Équipe A';
  String get teamAName => _teamAName;

  String _teamBName = 'Équipe B';
  String get teamBName => _teamBName;

  String _teamAColor = 'rouge';
  String get teamAColor => _teamAColor;

  String _teamBColor = 'bleu';
  String get teamBColor => _teamBColor;

  int _durationMinutes = 90;
  int get durationMinutes => _durationMinutes;

  bool _isCreating = false;
  bool get isCreating => _isCreating;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─────────────── Actions ───────────────

  void selectSport(SportType sport) {
    _selectedSport = sport;
    _durationMinutes = sport.matchDurationMinutes > 0
        ? sport.matchDurationMinutes
        : 90;
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

  void setDuration(int minutes) {
    _durationMinutes = minutes;
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

  /// Crée le match et retourne l'objet [GameMatch] ou null si erreur.
  Future<GameMatch?> startMatch() async {
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
      );
      final teamB = Team(
        id: _uuid.v4(),
        name: _teamBName.trim(),
        color: _teamBColor.trim(),
      );

      final match = await _repository.createMatch(
        sport: _selectedSport,
        teamA: teamA,
        teamB: teamB,
        durationMinutes: _durationMinutes,
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
}
