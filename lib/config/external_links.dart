const supportEmail = 'support@tyleryates.me';

const privacyPolicyUrl = 'https://tyleryates.me/unbound/privacy';

Uri get supportEmailUri => Uri(scheme: 'mailto', path: supportEmail);

Uri? get privacyPolicyUri => Uri.tryParse(privacyPolicyUrl);
