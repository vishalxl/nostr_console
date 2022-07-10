import 'package:nostr_console/nostr_console.dart';
import 'package:test/test.dart';

void main() {
  test('PrintEmptyEvent', () {
    expect(EventData("non","","",1,1,[]).toString(), "");
  });
}
