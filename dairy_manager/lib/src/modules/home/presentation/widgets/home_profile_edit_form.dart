import 'package:flutter/material.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../auth/presentation/validators/auth_validators.dart';

class HomeProfileEditForm extends StatelessWidget {
  const HomeProfileEditForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.mobileController,
    required this.addressController,
    required this.shopNameController,
    required this.role,
    required this.loading,
    required this.onCancel,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController mobileController;
  final TextEditingController addressController;
  final TextEditingController shopNameController;
  final String role;
  final bool loading;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AppFormCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAuthTextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
              validator: AuthValidators.validateName,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            AppAuthTextField(
              controller: mobileController,
              keyboardType: TextInputType.phone,
              label: 'Mobile Number',
              icon: Icons.call_rounded,
              validator: AuthValidators.validateMobile,
            ),
            const SizedBox(height: AppSizes.fieldGap),
            AppAuthTextField(
              controller: addressController,
              textCapitalization: TextCapitalization.words,
              label: 'Display Address',
              icon: Icons.place_rounded,
              validator: AuthValidators.validateAddress,
            ),
            if (role == 'seller') ...[
              const SizedBox(height: AppSizes.fieldGap),
              AppAuthTextField(
                controller: shopNameController,
                textCapitalization: TextCapitalization.words,
                label: 'Shop Name (optional)',
                icon: Icons.storefront_rounded,
                validator: (_) => null,
              ),
            ],
            const SizedBox(height: AppSizes.sectionGap),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: loading ? null : onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Save Changes',
                    loading: loading,
                    onPressed: onSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
