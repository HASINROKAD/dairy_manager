import 'package:flutter/material.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../auth/data/models/user_model.dart';

class HomeUserInfoSection extends StatelessWidget {
  const HomeUserInfoSection({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
    );
  }
}
