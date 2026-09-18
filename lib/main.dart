import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:score_bot/data/repositories/match_repository.dart';
import 'package:score_bot/data/services/audio_service.dart';
import 'package:score_bot/data/services/gemini_service.dart';
import 'package:score_bot/data/services/storage_service.dart';
import 'package:score_bot/ui/core/theme/app_theme.dart';
import 'package:score_bot/ui/features/live/view_models/live_view_model.dart';
import 'package:score_bot/ui/features/live/views/live_view.dart';
import 'package:score_bot/ui/features/live/views/live_watch_view.dart';
import 'package:score_bot/ui/features/setup/view_models/setup_view_model.dart';
import 'package:score_bot/ui/features/setup/views/setup_view.dart';
import 'package:score_bot/ui/features/setup/views/setup_watch_view.dart';
import 'package:score_bot/ui/features/summary/views/summary_view.dart';
import 'package:score_bot/ui/features/summary/views/summary_watch_view.dart';
import 'package:score_bot/domain/models/match.dart';

final GetIt sl = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chargement des variables d'environnement
  await dotenv.load(fileName: '.env');

  // Initialisation du stockage local
  final storageService = StorageService();
  await storageService.init();

  // Injection de dépendances
  sl.registerSingleton<StorageService>(storageService);
  sl.registerSingleton<AudioService>(AudioService());
  sl.registerSingleton<GeminiService>(
    GeminiService(storageService: sl<StorageService>()),
  );
  sl.registerSingleton<MatchRepository>(
    MatchRepository(
      audioService: sl<AudioService>(),
      geminiService: sl<GeminiService>(),
      storageService: sl<StorageService>(),
    ),
  );

  runApp(const ScoreBotApp());
}

class ScoreBotApp extends StatelessWidget {
  const ScoreBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScoreBot',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    return switch (settings.name) {
      '/' => MaterialPageRoute(
          builder: (_) => _WatchOrPhoneSetupView(
            viewModel: SetupViewModel(
              matchRepository: sl<MatchRepository>(),
            ),
          ),
        ),
      '/live' => MaterialPageRoute(
          builder: (_) {
            final match = settings.arguments as GameMatch;
            final vm = LiveViewModel(
              matchRepository: sl<MatchRepository>(),
              initialMatch: match,
            );
            // Détecte si on tourne sur une montre (petite fenêtre)
            return _WatchOrPhoneView(viewModel: vm);
          },
        ),
      '/summary' => MaterialPageRoute(
          builder: (_) {
            final match = settings.arguments as GameMatch;
            final vm = SummaryViewModel(
              matchRepository: sl<MatchRepository>(),
              match: match,
            );
            return _WatchOrPhoneSummaryView(viewModel: vm);
          },
        ),
      _ => MaterialPageRoute(
          builder: (_) => const _NotFoundView(),
        ),
    };
  }
}

/// Détecte automatiquement si l'app tourne sur une petite surface (montre)
/// et affiche la vue live adaptée.
class _WatchOrPhoneView extends StatelessWidget {
  const _WatchOrPhoneView({required this.viewModel});
  final LiveViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Les montres Wear OS ont généralement < 250dp de largeur
    final isWatch = width < 250;

    return isWatch
        ? LiveWatchView(viewModel: viewModel)
        : LiveView(viewModel: viewModel);
  }
}

/// Détecte automatiquement si l'app tourne sur une montre et affiche la vue résumé adaptée.
class _WatchOrPhoneSummaryView extends StatelessWidget {
  const _WatchOrPhoneSummaryView({required this.viewModel});
  final SummaryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWatch = width < 250;

    return isWatch
        ? SummaryWatchView(viewModel: viewModel)
        : SummaryView(viewModel: viewModel);
  }
}

class _WatchOrPhoneSetupView extends StatelessWidget {
  const _WatchOrPhoneSetupView({required this.viewModel});
  final SetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWatch = width < 250;

    return isWatch
        ? SetupWatchView(viewModel: viewModel)
        : SetupView(viewModel: viewModel);
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: const Center(
        child: Text(
          '404 — Page introuvable',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}
