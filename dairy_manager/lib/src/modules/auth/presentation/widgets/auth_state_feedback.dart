import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/user_model.dart';
import '../cubit/auth_cubit.dart';

typedef AuthUserStateHandler =
    void Function(BuildContext context, UserModel user);
typedef AuthMessageHandler =
    void Function(BuildContext context, String message);

class AuthStateFeedback extends StatelessWidget {
  const AuthStateFeedback({
    super.key,
    required this.child,
    this.onAuthenticated,
    this.onProfileIncomplete,
    this.onSignUpSuccess,
    this.onError,
    this.showErrorSnackBar = true,
    this.showSignUpSuccessSnackBar = true,
    this.showLoadingBanner = true,
  });

  final Widget child;
  final AuthUserStateHandler? onAuthenticated;
  final AuthUserStateHandler? onProfileIncomplete;
  final AuthMessageHandler? onSignUpSuccess;
  final AuthMessageHandler? onError;
  final bool showErrorSnackBar;
  final bool showSignUpSuccessSnackBar;
  final bool showLoadingBanner;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated && onAuthenticated != null) {
          onAuthenticated!(context, state.user);
          return;
        }

        if (state is AuthProfileIncomplete && onProfileIncomplete != null) {
          onProfileIncomplete!(context, state.user);
          return;
        }

        if (state is AuthError && showErrorSnackBar) {
          if (onError != null) {
            onError!(context, state.message);
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
          return;
        }

        if (state is AuthSignUpSuccess) {
          if (showSignUpSuccessSnackBar) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
          if (onSignUpSuccess != null) {
            onSignUpSuccess!(context, state.message);
          }
        }
      },
      builder: (context, state) {
        if (!showLoadingBanner || state is! AuthLoading) {
          return child;
        }

        return Stack(
          children: [
            child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ],
        );
      },
    );
  }
}
