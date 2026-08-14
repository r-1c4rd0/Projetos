import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'core/theme_controller.dart';
import 'core/titans_theme.dart';
import 'firebase_options.dart';
import 'model/academy_models.dart';
import 'model/app_user.dart';
import 'screen/athlete_dashboard_screen.dart';
import 'screen/athlete_registration_screen.dart';
import 'screen/event_screen.dart';
// Telas
import 'screen/master_panel_screen.dart';
import 'screen/nutrition_screen.dart';
import 'screen/progress_screen.dart';
import 'screen/training_screen.dart';
// 🔒 Seleção de aluno (mestre → console do aluno)
import 'service/selected_student.dart';
import 'service/selected_student_scope.dart';
import 'service/session_lifecycle.dart';
import 'service/user_session.dart';

final ThemeController themeController = ThemeController(
  initialMode: ThemeMode.dark,
);

// ✅ Controller global do aluno selecionado (mestre)
final SelectedStudentController selectedStudentController =
    SelectedStudentController();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TitansApp());
}

class TitansApp extends StatefulWidget {
  const TitansApp({super.key});

  @override
  State<TitansApp> createState() => _TitansAppState();
}

class _TitansAppState extends State<TitansApp> {
  late final SessionLifecycleService _sessionLifecycleService;

  @override
  void initState() {
    super.initState();
    _sessionLifecycleService = SessionLifecycleService(
      selectedStudentController: selectedStudentController,
    )..register();
  }

  @override
  void dispose() {
    _sessionLifecycleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        // ✅ Scope global (qual aluno o mestre selecionou)
        return SelectedStudentScope(
          controller: selectedStudentController,
          child: MaterialApp(
            title: 'Titans BJJ',
            debugShowCheckedModeBanner: false,

            theme: buildTitansLightTheme(),
            darkTheme: buildTitansDarkTheme(),
            themeMode: themeController.mode,

            // Dica: melhora consistência de paddings e evita “quebras” estranhas na web
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: media.textScaler.clamp(
                    minScaleFactor: 0.9,
                    maxScaleFactor: 1.15,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },

            home: AuthGate(app: const HomeShell()),
          ),
        );
      },
    );
  }
}

/// Mantive seu leading de logo (in-memory por enquanto)
class AppLogoLeading extends StatelessWidget {
  const AppLogoLeading({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = InMemoryAcademyRepository();

    return FutureBuilder<AcademyProfile>(
      future: repo.get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final profile = snap.data!;
        if (profile.logoPath == null) return const SizedBox.shrink();

        final file = File(profile.logoPath!);
        if (!file.existsSync()) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.file(file),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // ✅ Corrigido: mestre = professor OU admin
  bool _isMaster(AppUser user) {
    return user.role == UserRole.professor && user.role == UserRole.admin;
  }

  List<Widget> _buildPages(BuildContext context) {
    final user = UserScope.of(context);

    // ✅ Mestre: NÃO tem Treinos/Progresso/Nutrição aqui.
    // Ele acessa essas telas SOMENTE pelo card do aluno, dentro do MasterPanel
    // (que abre o AthleteConsoleScreen com gate)
    if (_isMaster(user)) {
      return <Widget>[
        const MasterPanelScreen(),
        const EventScreen(),
        AthleteRegistrationScreen(academyId: user.academyId),
        // (Opcional)
        // AcademyScreen(),
        // ShoppingScreen(),
      ];
    }

    // ✅ Aluno: fluxo completo com 5 tabs
    return const <Widget>[
      AthleteDashboardScreen(),
      EventScreen(),
      TrainingScreen(),
      ProgressScreen(),
      NutritionScreen(),
    ];
  }

  List<NavigationDestination> _buildDestinations(BuildContext context) {
    final user = UserScope.of(context);

    if (_isMaster(user)) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Mestre',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_outlined),
          label: 'Eventos',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_add_alt_1_outlined),
          label: 'Matrícula',
        ),
        // NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Academia'),
        // NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Compras'),
      ];
    }

    return const [
      NavigationDestination(
        icon: Icon(Icons.grid_view_rounded),
        label: 'Início',
      ),
      NavigationDestination(icon: Icon(Icons.event_outlined), label: 'Eventos'),
      NavigationDestination(
        icon: Icon(Icons.fitness_center_outlined),
        label: 'Treinos',
      ),
      NavigationDestination(icon: Icon(Icons.trending_up), label: 'Progresso'),
      NavigationDestination(
        icon: Icon(Icons.restaurant_menu_outlined),
        label: 'Nutrição',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(context);
    final dest = _buildDestinations(context);

    // Proteção: se mudar role em runtime e índice estourar
    if (_index >= pages.length) _index = 0;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.92),
        elevation: 0,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: dest,
      ),
    );
  }
}
