import 'package:go_router/go_router.dart';

import '../features/about/licenses_screen.dart';
import '../features/about/privacy_screen.dart';
import '../features/editor/editor_screen.dart';
import '../features/export/export_screen.dart';
import '../features/go_pro/go_pro_screen.dart';
import '../features/home/all_projects_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';

/// App route names, referenced by widgets via `context.goNamed(...)` /
/// `context.pushNamed(...)`.
abstract final class Routes {
  Routes._();
  static const home = 'home';
  static const onboarding = 'onboarding';
  static const allProjects = 'allProjects';
  static const editor = 'editor';
  static const export = 'export';
  static const settings = 'settings';
  static const privacy = 'privacy';
  static const licenses = 'licenses';
  static const goPro = 'goPro';
}

/// Builds the app's [GoRouter]. Home → Editor → Export is a push-style
/// drill-down so the Android back button pops correctly. Created per app
/// instance so navigation state never leaks between tests. [initialLocation]
/// is `/onboarding` on first run, `/` thereafter.
GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      name: Routes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/projects',
      name: Routes.allProjects,
      builder: (context, state) => const AllProjectsScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: Routes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/editor',
      name: Routes.editor,
      builder: (context, state) => const EditorScreen(),
    ),
    GoRoute(
      path: '/export',
      name: Routes.export,
      builder: (context, state) => const ExportScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: Routes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/privacy',
      name: Routes.privacy,
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: '/licenses',
      name: Routes.licenses,
      builder: (context, state) => const LicensesScreen(),
    ),
    GoRoute(
      path: '/go-pro',
      name: Routes.goPro,
      builder: (context, state) => const GoProScreen(),
    ),
  ],
);
