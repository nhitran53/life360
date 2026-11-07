import 'package:flutter_test/flutter_test.dart';
import 'package:life360/models/models.dart';

void main() {
  test('invite links carry the friend code', () {
    expect(inviteLink('ME1234'), 'https://friend360.app/add/ME1234');
  });

  test('friendCodeFrom reads codes and invite links', () {
    expect(friendCodeFrom(' gia999 '), 'GIA999');
    expect(friendCodeFrom('https://friend360.app/add/GIA999'), 'GIA999');
    expect(friendCodeFrom('friend360.app/add/gia999?ref=sms'), 'GIA999');
    expect(friendCodeFrom(inviteLink('ALEX42')), 'ALEX42');
  });

  test('friendCodeFrom rejects things that are not codes', () {
    expect(friendCodeFrom(''), isNull);
    expect(friendCodeFrom('@alex.runs'), isNull);
    expect(friendCodeFrom('ab'), isNull);
    expect(friendCodeFrom('https://friend360.app/add/'), isNull);
  });
}
