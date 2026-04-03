class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/v1',
  );

  static const operatorUserId = String.fromEnvironment('OPERATOR_USER_ID', defaultValue: '');
  static const operatorOrganizationId = String.fromEnvironment('OPERATOR_ORGANIZATION_ID', defaultValue: '');
  static const operatorMemberRole = String.fromEnvironment('OPERATOR_MEMBER_ROLE', defaultValue: 'OPERATOR');
  static const operatorEmail = String.fromEnvironment('OPERATOR_USER_EMAIL', defaultValue: '');

  static const clientUserId = String.fromEnvironment('CLIENT_USER_ID', defaultValue: '');
  static const clientOrganizationId = String.fromEnvironment('CLIENT_ORGANIZATION_ID', defaultValue: '');
  static const clientId = String.fromEnvironment('CLIENT_ID', defaultValue: '');
  static const clientEmail = String.fromEnvironment('CLIENT_USER_EMAIL', defaultValue: '');

  static bool get hasOperatorAccess =>
      operatorUserId.isNotEmpty && operatorOrganizationId.isNotEmpty;

  static bool get hasClientAccess =>
      clientUserId.isNotEmpty &&
      clientOrganizationId.isNotEmpty &&
      clientId.isNotEmpty;
}
