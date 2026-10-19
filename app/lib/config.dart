/// Pass the backend URL at build time:
///   flutter run --dart-define=API_URL=http://192.168.1.5:8000
///
/// Android emulator can't reach "localhost" on your laptop — it needs 10.0.2.2.
const apiUrl =
    String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');
