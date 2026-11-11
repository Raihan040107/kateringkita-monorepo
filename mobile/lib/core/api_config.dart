/// Alamat dasar API. Emulator Android mencapai host lewat 10.0.2.2.
/// Rilis: `flutter build apk --dart-define=API_BASE_URL=https://.../api/v1`.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5000/api/v1',
);
