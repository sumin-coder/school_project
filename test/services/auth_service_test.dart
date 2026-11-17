import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:style_pulse/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('clearing the saved session prevents automatic login', () async {
    await AuthService.saveLoggedInUserEmail('user@example.com');

    await AuthService.clearSavedLoggedInUserEmail();

    expect(await AuthService.getSavedLoggedInUserEmail(), isNull);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'style_pulse_explicitly_logged_out',
      ),
      isTrue,
    );
  });

  test('explicit logout overrides a stale saved email', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('style_pulse_logged_in_email', 'old@example.com');
    await prefs.setBool('style_pulse_explicitly_logged_out', true);

    expect(await AuthService.getSavedLoggedInUserEmail(), isNull);
  });
}
