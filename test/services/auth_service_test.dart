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
  });
}
