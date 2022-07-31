import 'package:nostr_console/nostr_console.dart';
import 'package:test/test.dart';


EventData exampleEdata = EventData("id", "pubkey",  1111111, 1, "content", "", [], [], []);
EventData exampleEdataChild = EventData("id", "pubkey", 1111111, 1, "content child", "", [], [], []);

Event exampleEvent = Event('event', 'id', exampleEdata, ['relay name']);
Event exampleEventChild = Event('event', 'id', exampleEdataChild, ['relay name']);

Tree exampleNode = Tree(exampleEvent, []);
Tree exampleNodeChild = Tree(exampleEventChild, []);



void main() {
  test('PrintEmptyEvent', () {
    expect(EventData("non","",1,1,"", "", [], [], []).toString(), "");
  });

  test('printEventNode', () {
    Tree node = exampleNode;
    Tree childNode = exampleNodeChild;
    Event     cChild = exampleEventChild;

    childNode.addChild(cChild);
    node.addChildNode(childNode);
    node.addChildNode(childNode);

    print("node");
    node.printTree(0, false);

  });
}
