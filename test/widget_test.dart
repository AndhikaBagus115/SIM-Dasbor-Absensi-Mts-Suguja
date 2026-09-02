import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin_mts/web_admin/core/constants.dart';

void main() {
  test('AppConstants schoolName is defined properly', () {
    expect(AppConstants.schoolName, isNotEmpty);
    expect(AppConstants.schoolName, contains('Sunan Gunung Jati'));
  });
}
