/// Friend invites: a shareable link built from a friend code, and reading a
/// code back out of whatever someone pasted.
library;

/// TODO: point at the real domain and handle the link in the app
/// (universal links / app links) once we have one.
const inviteLinkBase = 'https://friend360.app/add/';

/// "ME1234" → "https://friend360.app/add/ME1234".
String inviteLink(String friendCode) => '$inviteLinkBase$friendCode';

final _codePattern = RegExp(r'^[A-Z0-9]{4,10}$');

/// The friend code in [input], or null if it doesn't look like one.
///
/// Accepts a bare code in any case ("gia999") or an invite link
/// ("https://friend360.app/add/GIA999?ref=sms").
String? friendCodeFrom(String input) {
  var text = input.trim();
  final add = text.lastIndexOf('/add/');
  if (add != -1) {
    text = text.substring(add + '/add/'.length).split(RegExp(r'[/?#]')).first;
  }
  final code = text.toUpperCase();
  return _codePattern.hasMatch(code) ? code : null;
}
