import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_routes.dart';
import 'core/services/fcm_service.dart';
import 'features/admin/presentation/bloc/admin_bloc.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';
import 'features/splash/presentation/pages/splash_page.dart';
import 'features/user/presentation/bloc/user_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase immediately (required for background handler)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Show app immediately - avoid white screen from blocking on FCM init
  runApp(const MyApp());

  // Initialize FCM in background (token, permissions, etc.) - don't block UI
  unawaited(FCMService().initialize());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (context) => AuthRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            )..add(CheckAuthStatusEvent()),
          ),
          BlocProvider<AdminBloc>(
            create: (context) => AdminBloc(),
          ),
          BlocProvider<UserBloc>(
            create: (context) => UserBloc(),
          ),
          BlocProvider<NotificationBloc>(
            create: (context) => NotificationBloc(),
          ),
        ],
        // Every logged-in screen uses the black theme; splash/login stay light.
        child: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (previous, current) =>
              (previous is AuthAuthenticated) != (current is AuthAuthenticated),
          builder: (context, authState) => MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: authState is AuthAuthenticated
                ? AppDarkTheme.theme
                : AppTheme.lightTheme,
            home: const SplashPage(),
            routes: AppRoutes.routes,
          ),
        ),
      ),
    );
  }
}

