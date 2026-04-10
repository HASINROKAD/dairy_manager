import 'package:flutter/material.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
    required this.onProfileTap,
    required this.onLogoutTap,
  });

  final VoidCallback onProfileTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DrawerHeader(
              margin: EdgeInsets.zero,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Menu',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Profile'),
              onTap: onProfileTap,
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Logout'),
              onTap: onLogoutTap,
            ),
          ],
        ),
      ),
    );
  }
}
