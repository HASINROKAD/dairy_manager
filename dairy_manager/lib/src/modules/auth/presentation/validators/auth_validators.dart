class AuthValidators {
  const AuthValidators._();

  static String? validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Name is required';
    }
    if (text.length < 2) {
      return 'Name must be at least 2 characters';
    }
    final nameRegex = RegExp(r"^[a-zA-Z ]+$");
    if (!nameRegex.hasMatch(text)) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  static String? validateMobile(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Mobile number is required';
    }
    final phoneRegex = RegExp(r'^\d{10}$');
    if (!phoneRegex.hasMatch(text)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Email is required';
    }

    if (text.length > 254 || text.contains(' ')) {
      return 'Enter a valid email address';
    }

    final parts = text.split('@');
    if (parts.length != 2) {
      return 'Enter a valid email address';
    }

    final local = parts[0];
    final domain = parts[1];

    if (local.isEmpty || local.length > 64) {
      return 'Enter a valid email address';
    }

    if (domain.isEmpty || domain.length > 253) {
      return 'Enter a valid email address';
    }

    if (local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..') ||
        domain.startsWith('.') ||
        domain.endsWith('.') ||
        domain.contains('..')) {
      return 'Enter a valid email address';
    }

    final localRegex = RegExp(r"^[A-Za-z0-9.!#\$%&'*+/=?^_`{|}~-]+$");
    if (!localRegex.hasMatch(local)) {
      return 'Enter a valid email address';
    }

    final domainRegex = RegExp(
      r'^(?=.{1,253}$)(?!-)(?:[A-Za-z0-9-]{1,63}\.)+[A-Za-z]{2,63}$',
    );
    if (!domainRegex.hasMatch(domain)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Password is required';
    }
    if (text.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateAddress(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Address is required';
    }
    if (text.length < 8) {
      return 'Address must be at least 8 characters';
    }
    return null;
  }
}
