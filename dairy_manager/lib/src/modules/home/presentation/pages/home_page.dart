import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../../../core/utility/routes/app_routes.dart';
import '../../../auth/auth_barrel.dart';
import '../../data/repositories/home_repository.dart';
import '../../../milk/data/repositories/milk_repository.dart';
import '../../home_barrel.dart';
import '../widgets/customer_ledger_panel.dart';
import '../widgets/home_drawer.dart';
import '../widgets/notification_sheet.dart';
import '../widgets/seller_dashboard_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeRepository _homeRepository;
  late final HomeNotificationsCubit _notificationsCubit;

  @override
  void initState() {
    super.initState();
    _homeRepository = HomeRepository();
    _notificationsCubit = HomeNotificationsCubit(repository: _homeRepository)
      ..loadUnreadCount();
  }

  @override
  void dispose() {
    _notificationsCubit.close();
    super.dispose();
  }

  String _normalizedRole(String? role) => (role ?? '').trim().toLowerCase();

  Future<void> _openFeatureScreen({
    required String featureKey,
    required String role,
    required MilkRepository repository,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeFeaturePage(
          featureKey: featureKey,
          role: role,
          homeRepository: _homeRepository,
          milkRepository: repository,
        ),
      ),
    );
  }

  Widget _quickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rolePanel({
    required BuildContext context,
    required UserModel user,
    required String role,
    required MilkRepository repository,
  }) {
    if (role == 'customer') {
      return CustomerLedgerPanel(
        repository: repository,
        userLatitude: user.latitude,
        userLongitude: user.longitude,
        onOpenFeature: (featureKey) {
          return _openFeatureScreen(
            featureKey: featureKey,
            role: role,
            repository: repository,
          );
        },
      );
    }

    if (role == 'seller') {
      return SellerDashboardPanel(
        repository: repository,
        onOpenFeature: (featureKey) {
          return _openFeatureScreen(
            featureKey: featureKey,
            role: role,
            repository: repository,
          );
        },
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Theme.of(context).colorScheme.error),
      ),
      child: const Text(
        'Role is not configured yet. Contact admin to assign seller/customer role.',
      ),
    );
  }

  Future<void> _openNotificationsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: _notificationsCubit,
        child: const NotificationSheet(),
      ),
    );

    await _notificationsCubit.loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final SystemUiOverlayStyle statusStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
    );

    return BlocBuilder<AuthCubit, AuthState>(
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
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.profileSetup, (route) => false);
          });
          return const SizedBox.shrink();
        }

        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = state.user;
        final repository = MilkRepository();
        final roleFromProfile = _normalizedRole(user.role);
        final bool isSeller = roleFromProfile == 'seller';
        final drawerRole = roleFromProfile.isNotEmpty
            ? roleFromProfile
            : 'unknown';

        final quickActions = isSeller
            ? <({String key, String label, IconData icon})>[
                (
                  key: 'seller_requests',
                  label: 'Requests',
                  icon: Icons.group_add_rounded,
                ),
                (
                  key: 'seller_capacity',
                  label: 'Capacity',
                  icon: Icons.tune_rounded,
                ),
                (
                  key: 'seller_billing',
                  label: 'Billing',
                  icon: Icons.receipt_long_outlined,
                ),
              ]
            : <({String key, String label, IconData icon})>[
                (
                  key: 'customer_join',
                  label: 'Join',
                  icon: Icons.storefront_outlined,
                ),
                (
                  key: 'customer_billing',
                  label: 'Billing',
                  icon: Icons.receipt_long_outlined,
                ),
              ];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 4,
            toolbarHeight: 64,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dairy Hub',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'daily operations',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            systemOverlayStyle: statusStyle,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.96),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              ),
            ),
            leading: Builder(
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.only(left: 12, top: 10, bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.45),
                        ),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                      ),
                      child: Icon(
                        Icons.menu_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
            actions: [
              BlocProvider.value(
                value: _notificationsCubit,
                child: BlocBuilder<HomeNotificationsCubit, HomeNotificationsState>(
                  builder: (context, notificationState) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: 12,
                        top: 10,
                        bottom: 10,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _openNotificationsSheet,
                        child: Container(
                          width: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.45),
                            ),
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.notifications_none_rounded),
                              if (notificationState.unreadCount > 0)
                                Positioned(
                                  right: -4,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      notificationState.unreadCount > 99
                                          ? '99+'
                                          : '${notificationState.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          drawer: HomeDrawer(
            userName: user.name,
            userId: user.uid,
            activeRole: drawerRole,
            onProfileTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HomeProfilePage(user: user),
                ),
              );
            },
            onLogoutTap: () {
              Navigator.of(context).pop();
              context.read<AuthCubit>().logout();
            },
            onFeatureTap: (featureKey) {
              Navigator.of(context).pop();
              _openFeatureScreen(
                featureKey: featureKey,
                role: drawerRole,
                repository: repository,
              );
            },
          ),
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick actions',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: quickActions
                            .map(
                              (action) => _quickActionButton(
                                label: action.label,
                                icon: action.icon,
                                onTap: () {
                                  _openFeatureScreen(
                                    featureKey: action.key,
                                    role: drawerRole,
                                    repository: repository,
                                  );
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 18),
                      FutureBuilder<IdTokenResult?>(
                        future: FirebaseAuth.instance.currentUser
                            ?.getIdTokenResult(),
                        builder: (context, snapshot) {
                          final roleFromToken = _normalizedRole(
                            snapshot.data?.claims?['role']?.toString(),
                          );

                          final resolvedRole = roleFromProfile.isNotEmpty
                              ? roleFromProfile
                              : roleFromToken;

                          if (resolvedRole == 'seller' ||
                              resolvedRole == 'customer') {
                            return _rolePanel(
                              context: context,
                              user: user,
                              role: resolvedRole,
                              repository: repository,
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Theme.of(context).colorScheme.surface,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Role not detected for this account.',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Profile role: ${user.role ?? 'null'}, token role: ${snapshot.data?.claims?['role'] ?? 'null'}.',
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Please logout and login again after role assignment.',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
