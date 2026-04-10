import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../../../core/utility/routes/app_routes.dart';
import '../../auth_barrel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is AuthUnauthenticated || state is AuthInitial) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
            });
            return const SizedBox.shrink();
          }

          if (state is AuthProfileIncomplete) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.profileSetup,
                (route) => false,
              );
            });
            return const SizedBox.shrink();
          }

          if (state is! AuthAuthenticated) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = state.user;

          return AppPageBody(
            maxWidth: AppSizes.maxHomeWidth,
            child: AppFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.read<AuthCubit>().logout(),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Logout'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('You are logged in with Firebase email auth.'),
                  const SizedBox(height: AppSizes.sectionGap),
                  AppInfoTile(
                    icon: Icons.badge_rounded,
                    label: 'User ID',
                    value: user.uid,
                  ),
                  AppInfoTile(
                    icon: Icons.alternate_email_rounded,
                    label: 'Email',
                    value: user.email,
                  ),
                  AppInfoTile(
                    icon: Icons.call_rounded,
                    label: 'Mobile Number',
                    value: user.mobileNumber ?? 'Not set',
                  ),
                  AppInfoTile(
                    icon: Icons.verified_user_rounded,
                    label: 'Role',
                    value: (user.role ?? 'Not set').toUpperCase(),
                  ),
                  AppInfoTile(
                    icon: Icons.place_rounded,
                    label: 'Display Address',
                    value: user.displayAddress ?? 'Not set',
                  ),
                  if (user.role == 'seller')
                    AppInfoTile(
                      icon: Icons.store_mall_directory_rounded,
                      label: 'Shop Name',
                      value: user.shopName ?? 'Not set',
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
