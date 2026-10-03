import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:score_bot/data/repositories/match_repository.dart';
import 'package:score_bot/domain/models/game_event.dart';
import 'package:score_bot/domain/models/match.dart';

/// ViewModel gérant la liste des matchs archivés et l'exportation vers WhatsApp.
class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({required MatchRepository matchRepository})
    : _repository = matchRepository {
    loadMatches();
  }

  final MatchRepository _repository;

  List<GameMatch> _matches = [];
  List<GameMatch> get matches => List.unmodifiable(_matches);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Recharge la liste des matchs enregistrés depuis le stockage Hive.
  void loadMatches() {
    _isLoading = true;
    notifyListeners();
    _matches = _repository.listMatches();
    _isLoading = false;
    notifyListeners();
  }

  /// Supprime définitivement un match de l'historique et ses événements.
  Future<void> deleteMatch(String matchId) async {
    await _repository.deleteMatch(matchId);
    loadMatches();
  }

  /// Récupère les événements d'un match donné.
  List<GameEvent> getEventsForMatch(String matchId) {
    return _repository.getEvents(matchId);
  }

  /// Génère une feuille de match formatée WhatsApp pour un match de l'historique.
  String generateWhatsAppReportForMatch(GameMatch match) {
    final events = _repository.getEvents(match.id);
    final buf = StringBuffer();
    buf.writeln('🏆 *SCOREBOT — FEUILLE DE MATCH*');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('${match.sport.emoji} *Sport :* ${match.sport.label}');
    final d = match.startTime;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
    buf.writeln('📅 *Date :* $dateStr à $timeStr');
    if (match.durationMinutes > 0) {
      buf.writeln('⏱️ *Durée :* ${match.durationMinutes} min');
    }
    buf.writeln('');
    buf.writeln(
      '🔴 *${match.teamA.name}*  *${match.scoreA} — ${match.scoreB}*  *${match.teamB.name}* 🔵',
    );
    if (match.scoreA == match.scoreB) {
      buf.writeln('🤝 *Résultat :* Match nul');
    } else {
      final winner =
          match.scoreA > match.scoreB ? match.teamA.name : match.teamB.name;
      buf.writeln('🎉 *Vainqueur :* $winner');
    }
    buf.writeln('━━━━━━━━━━━━━━━━━━━━');

    if (events.isNotEmpty) {
      buf.writeln('⏱️ *FIL DU MATCH :*');
      for (final event in events) {
        final teamName =
            event.teamId == match.teamA.id
                ? match.teamA.name
                : match.teamB.name;

        final desc = switch (event) {
          GoalEvent(:final scorerName, :final assistName) =>
            '${event.type.emoji} ${event.minute}\' *${scorerName ?? "But"}*${assistName != null ? " _(passe: $assistName)_" : ""} — $teamName',
          CardEvent(:final playerName) =>
            '${event.type.emoji} ${event.minute}\' *${playerName ?? "?"}* — $teamName',
          _ =>
            '${event.type.emoji} ${event.minute}\' *${event.type.label}* — $teamName',
        };

        buf.writeln(desc);
      }
      buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    }

    buf.writeln('\n🤖 _Feuille de match officielle générée par ScoreBot_');
    return buf.toString();
  }

  /// Partage directement sur WhatsApp la feuille de match.
  Future<void> shareMatchOnWhatsApp(GameMatch match) async {
    final text = generateWhatsAppReportForMatch(match);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject:
            '🏆 Feuille de match : ${match.teamA.name} vs ${match.teamB.name}',
      ),
    );
  }
}
