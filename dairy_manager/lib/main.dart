import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constant/theme/app_theme.dart';
import 'core/utility/routes/app_router.dart';
import 'core/utility/routes/app_routes.dart';
import 'src/modules/auth/auth_barrel.dart';

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
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.authGate,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
