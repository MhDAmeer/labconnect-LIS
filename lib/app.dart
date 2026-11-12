import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'core/services/report_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/facility_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/patient_repository.dart';
import 'features/login/login_screen.dart';
import 'features/shell/app_shell.dart';
import 'state/session_controller.dart';
import 'widgets/common_widgets.dart';

/// Builds the object graph once and starts the app.
///
///   TokenStorage -> ApiClient -> repositories -> SessionController
class LabConnectApp extends StatefulWidget {
  const LabConnectApp({super.key});

  @override
  State<LabConnectApp> createState() => _LabConnectAppState();
}

class _LabConnectAppState extends State<LabConnectApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final TokenStorage _tokens;
  late final ApiClient _api;
  late final AuthRepository _auth;
  late final PatientRepository _patients;
  late final FacilityRepository _facilities;
  late final OrderRepository _orders;
  late final ReportService _reports;
  late final SessionController _session;

  /// When the app left the foreground; null while it is in front.
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tokens = TokenStorage();
    _api = ApiClient(tokens: _tokens);
    _auth = AuthRepository(api: _api, tokens: _tokens);
    _patients = PatientRepository(_api);
    _facilities = FacilityRepository(_api);
    _orders = OrderRepository(_api);
    _reports = ReportService(_orders);
    _session = SessionController(auth: _auth, reports: _reports);

    // A refused refresh token means the session is over.
    _api.onSessionExpired = () {
      _session.endSession('Your session has expired. Please sign in again.');
    };

    _session.addListener(_onSessionChanged);
    _session.restore();
  }

  /// When the user is signed out, drop any screens still on the navigator so
  /// patient data can't linger behind the Login screen.
  void _onSessionChanged() {
    if (_session.status == SessionStatus.signedOut) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final left = _backgroundedAt;
        _backgroundedAt = null;
        if (left != null &&
            DateTime.now().difference(left) > AppConfig.backgroundLockAfter &&
            _session.status == SessionStatus.signedIn) {
          // Patient data: after a long time away, require a fresh sign-in.
          _session.logout(
            notice:
                'You were signed out because the app was inactive for a while.',
          );
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: _auth),
        Provider<PatientRepository>.value(value: _patients),
        Provider<FacilityRepository>.value(value: _facilities),
        Provider<OrderRepository>.value(value: _orders),
        Provider<ReportService>.value(value: _reports),
        ChangeNotifierProvider<SessionController>.value(value: _session),
      ],
      child: MaterialApp(
        title: 'LabConnect',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: AppTheme.light(),
        home: const _RootGate(),
      ),
    );
  }
}

/// Chooses between the splash, Login and the main app from the session
/// status.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final status = context.select((SessionController s) => s.status);

    switch (status) {
      case SessionStatus.starting:
        return const AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(body: LoadingView()),
        );
      case SessionStatus.signedOut:
        return const LoginScreen();
      case SessionStatus.signedIn:
        return const AppShell();
    }
  }
}
