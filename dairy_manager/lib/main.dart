import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import 'core/constant/theme/app_theme.dart';
import 'core/utility/network/connectivity_recovery_bus.dart';
import 'core/utility/routes/app_router.dart';
import 'core/utility/routes/app_routes.dart';
import 'src/modules/auth/auth_barrel.dart';

final GlobalKey<ScaffoldMessengerState> _rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const DairyManagerApp());
}

class DairyManagerApp extends StatelessWidget {
  const DairyManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Dairy Manager',
        scaffoldMessengerKey: _rootScaffoldMessengerKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.authGate,
        onGenerateRoute: AppRouter.onGenerateRoute,
        builder: (context, child) {
          return _AppGlobalGuard(child: child ?? const SizedBox.shrink());
        },
      ),
    );
  }
}

class _AppGlobalGuard extends StatefulWidget {
  const _AppGlobalGuard({required this.child});

  final Widget child;

  @override
  State<_AppGlobalGuard> createState() => _AppGlobalGuardState();
}

class _AppGlobalGuardState extends State<_AppGlobalGuard> {
  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _isOffline = false;
  bool _startupNoticeShown = false;

  @override
  void initState() {
    super.initState();
    _initConnectivityMonitor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartupNoticeIfNeeded();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivityMonitor() async {
    final connectivity = Connectivity();

    final initial = await connectivity.checkConnectivity();
    _applyConnectivityState(initial);

    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      _applyConnectivityState,
    );
  }

  void _applyConnectivityState(dynamic result) {
    Iterable<ConnectivityResult> states;

    if (result is ConnectivityResult) {
      states = <ConnectivityResult>[result];
    } else if (result is List<ConnectivityResult>) {
      states = result;
    } else if (result is Iterable<ConnectivityResult>) {
      states = result;
    } else {
      states = const <ConnectivityResult>[];
    }

    final offline =
        states.isEmpty ||
        states.every((item) => item == ConnectivityResult.none);
    final wasOffline = _isOffline;

    if (!mounted || offline == _isOffline) {
      return;
    }

    setState(() {
      _isOffline = offline;
    });

    if (wasOffline && !offline) {
      ConnectivityRecoveryBus.emitRecovery();
      _showMessage('Back online. Syncing latest data...');
    }
  }

  Future<void> _retryConnectivityAndSync() async {
    final current = await Connectivity().checkConnectivity();
    _applyConnectivityState(current);

    if (!mounted) {
      return;
    }

    if (_isOffline) {
      _showMessage('Still offline. Please enable mobile data or Wi-Fi.');
    }
  }

  bool get _supportsLocationPermissionPrompt {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  Future<void> _showStartupNoticeIfNeeded() async {
    if (!mounted || _startupNoticeShown) {
      return;
    }

    _startupNoticeShown = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Before You Continue'),
          content: const Text(
            'Please keep mobile data or Wi-Fi turned on while using the app for billing sync, maps, and live updates. '
            'Location permission is also needed for map and address features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
            if (_supportsLocationPermissionPrompt)
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _requestLocationPermission();
                },
                child: const Text('Allow Location'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Turn on location services to use map-based features.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage(
          'Location permission denied. You can allow it later in settings.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is permanently denied. Open app settings to allow it.',
        );
        await Geolocator.openAppSettings();
        return;
      }

      _showMessage('Location permission granted.');
    } catch (_) {
      _showMessage('Unable to check location permission on this device.');
    }
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }

    final messenger = _rootScaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Theme.of(context).colorScheme.error,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: Theme.of(context).colorScheme.onError,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Internet is offline. Please keep data or Wi-Fi on for smooth app usage.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _retryConnectivityAndSync,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
