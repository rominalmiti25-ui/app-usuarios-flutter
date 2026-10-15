/// URL base del backend. Se cambia al compilar sin tocar el código:
///   flutter run --dart-define=API_URL=http://10.0.2.2:5000      (emulador Android → Flask local)
///   flutter build apk --dart-define=API_URL=https://tu-app.vercel.app
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://tu-app.vercel.app',
);
