import 'package:nostr_console/event_ds.dart';
import 'package:test/test.dart';
import 'package:nostr_console/tree_ds.dart';


EventData exampleEdata = EventData("id1", "pubkey",  1111111, 1, "content", [], [], [], [[]], {});
EventData exampleEdataChild = EventData("id2", "pubkey", 1111111, 1, "content child", [], [], [], [[]], {});

Event exampleEvent = Event('event', 'id3', exampleEdata, ['relay name'], "[json]");
Event exampleEventChild = Event('event', 'id4', exampleEdataChild, ['relay name'], "[json]");

Tree exampleNode = Tree(exampleEvent, [], {}, [], false, {});
Tree exampleNodeChild = Tree(exampleEventChild, [], {}, [], false, {});

void main() {
  test('PrintEmptyEvent', () {
    expect(EventData("non","",1,1,"", [], [], [], [[]], {}).toString(), "");
  });

  test('printEventNode', () {
    Tree  node      = exampleNode;
    Tree  childNode = exampleNodeChild;
    Event cChild    = exampleEventChild;

    childNode.addChild(cChild);
    node.addChildNode(childNode);
    node.addChildNode(childNode);
  
    node.printTree(0, DateTime.now().subtract(Duration(days:1)), selectAll);
  });

  test('createNodeTree_ordered', () {
    
    Event exampleEvent1 = Event.fromJson('["EVENT","latest",{"id":"167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de","pubkey":"e37d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722388,"kind":1,"tags":[],"content":"nostr is not federated is it? this is like a global feed of all nostr freaks?","sig":"6db0b287015d9529dfbacef91561cb4e32afd6968edd8454867b8482bde01452e17b6f3de69bffcb2d9deba2a52d3c9ff82e04f7b18eb32428daf7eab5fd27c5"}]', "");
    Event exampleEvent2 = Event.fromJson('["EVENT","latest",{"id":"f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67","pubkey":"e37d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722463,"kind":1,"tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de"]],"content":"I don’t get the technical stuff about relays and things","sig":"9f68031687214a24862226f291e3baadd956dc14ba9c5c552f8c881a40aacd34feda667ef4e4b09711cd43950eec2d272d5b11bd7636de5f457f38f31eaff398"}]', "");
    Event exampleEvent3 = Event.fromJson('["EVENT","latest",{"id":"dfc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"e37d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722537,"kind":1,"tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de"],["e","f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67"]],"content":"different clients make sense to me. I can use different clients to access nostr but is just one giant soup like twitter","sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]', "");

    Set<Event> listEvents = {exampleEvent1, exampleEvent2, exampleEvent3};

    Tree node = Tree.fromEvents(listEvents);
    node.printTree(0, DateTime.now().subtract(Duration(days:1000)), selectAll);
    print("=========================");
  });

  test('createNodeTree_unordered1', () {
    
    Event exampleEvent1 = Event.fromJson('["EVENT","latest",{"id":"167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de","pubkey":"e37d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722388,"kind":1,"tags":[],"content":"nostr is not federated is it? this is like a global feed of all nostr freaks?","sig":"6db0b287015d9529dfbacef91561cb4e32afd6968edd8454867b8482bde01452e17b6f3de69bffcb2d9deba2a52d3c9ff82e04f7b18eb32428daf7eab5fd27c5"}]', "");
    Event exampleEvent2 = Event.fromJson('["EVENT","latest",{"id":"f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67","pubkey":"e37d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722463,"kind":1,"tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de"]],"content":"I don’t get the technical stuff about relays and things","sig":"9f68031687214a24862226f291e3baadd956dc14ba9c5c552f8c881a40aacd34feda667ef4e4b09711cd43950eec2d272d5b11bd7636de5f457f38f31eaff398"}]', "");
    Event exampleEvent3 = Event.fromJson('["EVENT","latest",{"id":"dfc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"e37d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722537,"kind":1,"tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de"],["e","f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67"]],"content":"different clients make sense to me. I can use different clients to access nostr but is just one giant soup like twitter","sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]', "");

    Set<Event> listEvents = { exampleEvent3, exampleEvent2,  exampleEvent1};

    Tree node = Tree.fromEvents(listEvents);
    node.printTree(0, DateTime.now().subtract(Duration(days:1000)), selectAll); // will test for ~1000 days
  });


}
