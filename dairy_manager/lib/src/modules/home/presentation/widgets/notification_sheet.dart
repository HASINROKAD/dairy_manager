import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_notifications_cubit.dart';

class NotificationSheet extends StatefulWidget {
  const NotificationSheet({super.key});

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  @override
  void initState() {
    super.initState();
    context.read<HomeNotificationsCubit>().loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: BlocBuilder<HomeNotificationsCubit, HomeNotificationsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (state.errorMessage != null && state.items.isEmpty) {
              return SizedBox(
                height: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not load notifications.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.read<HomeNotificationsCubit>().loadFeed();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      if (state.unreadCount > 0)
                        TextButton(
                          onPressed: () {
                            context
                                .read<HomeNotificationsCubit>()
                                .markAllRead();
                          },
                          child: const Text('Mark all read'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('No notifications yet.')),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: state.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return Card(
                            child: ListTile(
                              onTap: item.isRead
                                  ? null
                                  : () async {
                                      await context
                                          .read<HomeNotificationsCubit>()
                                          .markRead(item.id);
                                    },
                              title: Text(item.title),
                              subtitle: Text(item.message),
                              trailing: item.isRead
                                  ? const Icon(
                                      Icons.done,
                                      color: Colors.grey,
                                      size: 18,
                                    )
                                  : const Icon(
                                      Icons.fiber_manual_record,
                                      color: Colors.blue,
                                      size: 12,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
