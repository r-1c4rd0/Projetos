import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'core/theme_controller.dart';
import 'core/titans_theme.dart';
import 'firebase_options.dart';
import 'model/academy_models.dart';
import 'model/app_user.dart';
import 'repository/academy_repository.dart';
import 'screen/academy_screen.dart';
import 'screen/athlete_dashboard_screen.dart';
import 'screen/attendance_screen.dart';
import 'package:titans_bjj/screen/event_screen.dart';
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
import 'widgets/academy_branding.dart';

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

class AppLogoLeading extends StatefulWidget {
  const AppLogoLeading({super.key});

  @override
  State<AppLogoLeading> createState() => _AppLogoLeadingState();
}

class _AppLogoLeadingState extends State<AppLogoLeading> {
  Future<AcademyProfile>? _profileFuture;
  String? _academyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = UserScope.maybeScopeOf(context);
    final academyId = scope?.activeAcademyId.trim();
    if (academyId == null || academyId.isEmpty) return;
    if (_academyId == academyId && _profileFuture != null) return;

    _academyId = academyId;
    _profileFuture = AcademyRepository.instance.getAcademy(academyId);
  }

  @override
  Widget build(BuildContext context) {
    final future = _profileFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<AcademyProfile>(
      future: future,
      builder: (context, snap) {
        final branding = snap.data?.branding ?? const AcademyBranding();
        final primary = academyBrandColor(branding.primaryColor);
        final secondary = academyBrandColor(branding.secondaryColor);
        final accent = primary ?? secondary;
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  accent?.withValues(alpha: 0.10) ??
                  colorScheme.surfaceContainerHighest,
              border: Border.all(
                color:
                    accent?.withValues(alpha: 0.32) ??
                    colorScheme.onSurface.withValues(alpha: 0.10),
              ),
            ),
            child: ClipOval(
              child: SizedBox.square(
                dimension: 40,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: AcademyBrandLogo(
                    branding: branding,
                    size: 30,
                    fallbackSize: 30,
                  ),
                ),
              ),
            ),
          ),
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
    return user.role == UserRole.professor || user.role == UserRole.admin;
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
        const AttendanceScreen(),
        const AcademyScreen(),
        // (Opcional)
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
          icon: Icon(Icons.fact_check_outlined),
          label: 'Presen\u00e7a',
        ),
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          label: 'Academia',
        ),
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
