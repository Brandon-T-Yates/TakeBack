const supportEmail = 'support@tyler.yates.me';

// Set this to the final production URL before App Store submission.
const String? privacyPolicyUrl = null;

Uri get supportEmailUri => Uri(scheme: 'mailto', path: supportEmail);

Uri? get privacyPolicyUri {
  final value = privacyPolicyUrl;
  return value == null ? null : Uri.tryParse(value);
}
