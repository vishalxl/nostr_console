import 'dart:io';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/settings.dart';
import 'package:nostr_console/utils.dart';
import 'package:test/test.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/relays.dart';


EventData exampleEdata = EventData("id1", "pubkey",  1752181331, 1, "content", [], [], [], [[]], {});
EventData exampleEdataChild = EventData("id2", "pubkey", 1752181331, 1, "content child", [], [], [], [[]], {});

Event exampleEvent = Event('event', 'id3', exampleEdata, ['relay name'], "[json]");
Event exampleEventChild = Event('event', 'id4', exampleEdataChild, ['relay name'], "[json]");

Store exampleStore = Store([], {}, [], [], [], [], {});
Tree  exampleTree  = Tree.withoutStore(exampleEvent, []);

//bool skipTest = true;

//Relays relays = Relays({}, {}, {});


void main() async {
  relays = Relays({}, {}, {});
  gListRelayUrls = {};
  //gDebug = 1;
  
  test('invalid_relay', () async {

    String req = '["REQ","latest_live_all",{"limit":40000,"kinds":[0,1,3,4,5,6,7,40,41,42,104,140,141,142],"since":${getTimeSecondsAgo(gSecsLatestLive).toString()}}]';
    sendRequest({"wss://invalidurl1234123134.com"}, req);

  });

  test('printEventNode', () {
    Store  store     = exampleStore;
    Tree  tree       = exampleTree;
    Tree  treeChild  = Tree.withoutStore(exampleEvent, []);

    tree.setStore(store);
    treeChild.setStore(store);
    tree.children.add(treeChild);
    //store.printStoreTrees(1, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all);
  });




  test('createNodeTree_ordered', () {
    
    Event exampleEvent1 = Event.fromJson('["EVENT","latest",{"id":"167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722388,"kind":1,"tags":[],"content":"nostr is not federated is it? this is like a global feed of all nostr freaks?","sig":"6db0b287015d9529dfbacef91561cb4e32afd6968edd8454867b8482bde01452e17b6f3de69bffcb2d9deba2a52d3c9ff82e04f7b18eb32428daf7eab5fd27c5"}]', "");
    Event exampleEvent2 = Event.fromJson('["EVENT","latest",{"id":"f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722463,"kind":1,"tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de"]],"content":"I don’t get the technical stuff about relays and things","sig":"9f68031687214a24862226f291e3baadd956dc14ba9c5c552f8c881a40aacd34feda667ef4e4b09711cd43950eec2d272d5b11bd7636de5f457f38f31eaff398"}]', "");
    Event exampleEvent3 = Event.fromJson('["EVENT","latest",{"id":"dfc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722537,"kind":1,"tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de"],["e","f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67"]],"content":"different clients make sense to me. I can use different clients to access nostr but is just one giant soup like twitter","sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]', "");

    Set<Event> listEvents = {exampleEvent1, exampleEvent2, exampleEvent3};

    Store node = Store.fromEvents(listEvents);
    //print("top posts: ${node.topPosts.length}" );
    //print( node.topPosts[0].event.eventData.id );
    //node.printStoreTrees(0, DateTime.now().subtract(Duration(days: 2000)), (a) => true);
    //print("=========================");
  });



  test('createNodeTree_only2_1', () {



// ▄────────────
// █       137d9: Non                                                         |id: 167063, 11:29 PM Aug 5          2
//
//               137d9: event2 reply 1 to top 1                               |id: f3a267, 11:31 PM Aug 5          2
//
//                     137d9: event3 reply 2 to reply 1                       |id: dfc576, 11:32 PM Aug 5          1
//
//                                                                                                 █
//                                                                                     ────────────▀

    Event exampleEvent2 = Event.fromJson(
      """["EVENT","latest",{"id":"f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722463,
      "kind":1,
      "tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", "", "root"]],
      "content":"event2 reply 1 to top 1",
      "sig":"9f68031687214a24862226f291e3baadd956dc14ba9c5c552f8c881a40aacd34feda667ef4e4b09711cd43950eec2d272d5b11bd7636de5f457f38f31eaff398"}]""", "");
    
    Event exampleEvent3 = Event.fromJson(
      """["EVENT","latest",{"id":"dfc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722537,"kind":1,
      "tags":[
        ["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", "", "root"],
        ["e","f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67", "", "reply"]
      ],
      "content":"event3 reply 2 to reply 1",
      "sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]""", "");



    Set<Event> setEmpty = { };

    Store node = Store.fromEvents(setEmpty);
    expect(node.topPosts.length, 0);

    print(" createNodeTree_unordered_2212 : added none:");
    node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days
    print("node.count() = ${node.count()}");

    print("calling processIncomingEvents with event3");    
    Set<Event> newEvents3 = {exampleEvent3};
    node.processIncomingEvent(newEvents3);

    expect(node.topPosts.length, 1);
    expect ( node.topPosts[0].children.length, 1);
    node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days
    print("node.count() = ${node.count()}");


    print("calling processIncomingEvents with event2");    
    Set<Event> newEvents2 = { exampleEvent2 };
    node.processIncomingEvent(newEvents2);

    expect(node.topPosts.length, 1);
    expect ( node.topPosts[0].children.length, 1);
    node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days
    print("node.count() = ${node.count()}");

   // repeat event 
    print("AGAIN calling processIncomingEvents with event2");    
    node.processIncomingEvent(newEvents2);

    expect(node.topPosts.length, 1);
    expect ( node.topPosts[0].children.length, 1);
    node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days
    print("node.count() = ${node.count()}");


  });


  test('createNodeTree_unordered_reactions', () {



// ▄────────────
// █       137d9: top 1                                                |id: 167063, 11:29 PM Aug 5          2
//
//               137d9: reply 1 to top 1                               |id: f3a267, 11:31 PM Aug 5          2
//
//                     137d9: reaction                                 |id: dfc576, 11:32 PM Aug 5          kind 7 1
//
//               137d9: reply 2 to top 1                               |id: afc576, 11:32 PM Aug 5          2
//                                                                                                 █
//                                                                                     ────────────▀

    Event exampleEvent1 = Event.fromJson(
    """["EVENT","latest",
    {"id":"167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de",
    "pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
    "created_at":1659722388,
    "kind":1,
    "tags":[],
    "content":"top 1",
    "sig":"6db0b287015d9529dfbacef91561cb4e32afd6968edd8454867b8482bde01452e17b6f3de69bffcb2d9deba2a52d3c9ff82e04f7b18eb32428daf7eab5fd27c5"}]"""
  
    , "");
    
    Event exampleEvent2 = Event.fromJson(
      """["EVENT","latest",{"id":"f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722463,
      "kind":1,
      "content":"reply 1 to top 1",
      "tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", ""]],
      "sig":"9f68031687214a24862226f291e3baadd956dc14ba9c5c552f8c881a40aacd34feda667ef4e4b09711cd43950eec2d272d5b11bd7636de5f457f38f31eaff398"}]""", "");
    
    Event reactionEvent3 = Event.fromJson(
      """["EVENT","latest",{"id":"dfc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722537,
      "kind":7,
      "tags":[
        ["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", "", "root"],
        ["e","f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67", "", "reply"]
      ],
      "content":"+",
      "sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]""", "");


    Event exampleEvent4 = Event.fromJson(
      """["EVENT","latest",{"id":"afc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722538,"kind":1,
      "tags":[
        ["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", "", "root"]
      ],
      "content":"reply 2 to top 1",
      "sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]""", "");



    Set<Event> listEvents = {  reactionEvent3};

    Store node = Store.fromEvents(listEvents);
    
    
    expect(node.topPosts.length, 0);
    
    //print(" createNodeTree_unordered_2212 : added only one, only one should get printed:");
    //node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days
    
    Set<Event> newEvents = {exampleEvent2, exampleEvent1 , exampleEvent4};
    node.processIncomingEvent(newEvents);

    expect(node.topPosts.length, 1);
    expect ( node.topPosts[0].children.length, 2);
    //node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days

  });




  test('createNodeTree_unordered_2212', () {



// ▄────────────
// █       137d9: event1 top 1                                                |id: 167063, 11:29 PM Aug 5          2
//
//               137d9: event2 reply 1 to top 1                               |id: f3a267, 11:31 PM Aug 5          2
//
//                     137d9: event3 reply 2 to reply 1                       |id: dfc576, 11:32 PM Aug 5          1
//
//               137d9: event4 reply 2 to top 1                               |id: afc576, 11:32 PM Aug 5          2
//                                                                                                 █
//                                                                                     ────────────▀

    Event exampleEvent1 = Event.fromJson(
    """["EVENT","latest",
    {"id":"167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de",
    "pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
    "created_at":1659722388,
    "kind":1,
    "tags":[],
    "content":"event1 top 1",
    "sig":"6db0b287015d9529dfbacef91561cb4e32afd6968edd8454867b8482bde01452e17b6f3de69bffcb2d9deba2a52d3c9ff82e04f7b18eb32428daf7eab5fd27c5"}]"""
  
    , "");
    
    Event exampleEvent2 = Event.fromJson(
      """["EVENT","latest",{"id":"f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722463,
      "kind":1,
      "tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", "", "root"]],
      "content":"event2 reply 1 to top 1",
      "sig":"9f68031687214a24862226f291e3baadd956dc14ba9c5c552f8c881a40aacd34feda667ef4e4b09711cd43950eec2d272d5b11bd7636de5f457f38f31eaff398"}]""", "");
    
    Event exampleEvent3 = Event.fromJson(
      """["EVENT","latest",{"id":"dfc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722537,"kind":1,
      "tags":[
        ["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", "", "root"],
        ["e","f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67", "", "reply"]
      ],
      "content":"event3 reply 2 to reply 1",
      "sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]""", "");


    Event exampleEvent4 = Event.fromJson(
      """["EVENT","latest",{"id":"afc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722538,"kind":1,
      "tags":[
        ["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", "", "root"]
      ],
      "content":"event4 reply 2 to top 1",
      "sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]""", "");


    Set<Event> setEvent3 = {  exampleEvent3};

    Store node = Store.fromEvents(setEvent3);
    expect(node.topPosts.length, 1);
    expect ( node.topPosts[0].children.length, 1);
    expect ( node.topPosts[0].children[0].children.length, 0);

    print(" createNodeTree_unordered_2212 : added only one, only one should get printed:");
    node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days
    print("node.count() = ${node.count()}");

    print("calling processIncomingEvents with event4");    
    Set<Event> newEvents4 = {exampleEvent4};
    node.processIncomingEvent(newEvents4);

    expect(node.topPosts.length, 2);
    expect ( node.topPosts[0].children.length, 1);
    node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days
    print("node.count() = ${node.count()}");


    print("calling processIncomingEvents with event1");    
    Set<Event> newEvents1 = { exampleEvent1 };
    node.processIncomingEvent(newEvents1);

    expect(node.topPosts.length, 2);
    expect ( node.topPosts[0].children.length, 1);
    node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days
    print("node.count() = ${node.count()}");

    print("calling processIncomingEvents with 2");    
    Set<Event> newEvents2 = {  exampleEvent2};
    node.processIncomingEvent(newEvents2);

    expect(node.topPosts.length, 1);
    expect ( node.topPosts[0].event.eventData.pubkey, "137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3");
    expect ( node.topPosts[0].children.length, 2);

    node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days
    print("node.count() = ${node.count()}");


  });



  test('createNodeTree_unordered1', () {



// ▄────────────
// █       137d9: top 1                                                |id: 167063, 11:29 PM Aug 5          2
//
//               137d9: reply 1 to top 1                               |id: f3a267, 11:31 PM Aug 5          1
//
//                     137d9: reply 2 to reply 1                       |id: dfc576, 11:32 PM Aug 5          1
//
//               137d9: reply 2 to top 1                               |id: afc576, 11:32 PM Aug 5          2
//                                                                                                 █
//                                                                                     ────────────▀

    Event exampleEvent1 = Event.fromJson(
    """["EVENT","latest",
    {"id":"167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de",
    "pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
    "created_at":1659722388,
    "kind":1,
    "tags":[],
    "content":"top 1",
    "sig":"6db0b287015d9529dfbacef91561cb4e32afd6968edd8454867b8482bde01452e17b6f3de69bffcb2d9deba2a52d3c9ff82e04f7b18eb32428daf7eab5fd27c5"}]"""
  
    , "");
    
    Event exampleEvent2 = Event.fromJson(
      """["EVENT","latest",{"id":"f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722463,
      "kind":1,
      "tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", "", "root"]],
      "content":"reply 1 to top 1",
      "sig":"9f68031687214a24862226f291e3baadd956dc14ba9c5c552f8c881a40aacd34feda667ef4e4b09711cd43950eec2d272d5b11bd7636de5f457f38f31eaff398"}]""", "");
    
    Event exampleEvent3 = Event.fromJson(
      """["EVENT","latest",{"id":"dfc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722537,"kind":1,
      "tags":[
        ["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", "", "root"],
        ["e","f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67", "", "reply"]
      ],
      "content":"reply 2 to reply 1",
      "sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]""", "");


    Event exampleEvent4 = Event.fromJson(
      """["EVENT","latest",{"id":"afc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3",
      "created_at":1659722538,"kind":1,
      "tags":[
        ["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de", "", "root"]
      ],
      "content":"reply 2 to top 1",
      "sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]""", "");


    Set<Event> listEvents = { exampleEvent3, exampleEvent2};

    Store node = Store.fromEvents(listEvents);
    expect(node.topPosts.length, 1);
    expect ( node.topPosts[0].children.length, 1);
    expect ( node.topPosts[0].children[0].children.length, 1);

    print("ended test createNodeTree_unordered1");
    node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days
    
    Set<Event> newEvents = {exampleEvent1 , exampleEvent4};
    node.processIncomingEvent(newEvents);

    expect(node.topPosts.length, 1);
    expect ( node.topPosts[0].children.length, 2);
    node.printStoreTrees(0, DateTime.now().subtract(Duration(days:2000)), selectorTrees_all); // will test for ~1000 days

  });


  test('make_paragraph', () {
    gTextWidth = 120;
    //print(gNumLeftMarginSpaces);
    //print(gTextWidth);

    String paragraph =  """
1 Testing paragraph with multiple lines. Testing paragraph with multiple lines. Testing paragraph with multiple lines. Testing paragraph with multiple lines. 
2 Testing paragraph with multiple lines. Testing paragraph with multiple lines. Testing paragraph with multiple lines. 
3 Testing paragraph with multiple lines. 

5 Testing paragraph with multiple lines. Testing paragraph with multiple lines. Testing paragraph with multiple lines. 
6 Testing paragraph with multiple lines. 
7 Testing paragraph with multiple lines. Testing paragraph with multiple lines.  89 words
8 Testing paragraph with multiple lines. Testing paragraph with multiple lines.   90 words
9 Testing paragraph with multiple lines. Testing paragraph with multiple lines.    91 words
10 Testing paragraph with multiple lines. Testing paragraph with multiple lines.    92 words


11 Testing paragraph with multiple lines. Testing paragraph with multiple lines. 89 words



12 Testing paragraph with multiple lines. Testing paragraph with multiple lines.  90 words



13 Testing paragraph with multiple lines. Testing paragraph with multiple lines.   91 words



14 Testing paragraph with multiple lines. Testing paragraph with multiple lines.    92 words




a""";


String expectedResult = 
"""
1 Testing paragraph with multiple lines. Testing paragraph with multiple lines. Testing
                              paragraph with multiple lines. Testing paragraph with multiple lines. 
                              2 Testing paragraph with multiple lines. Testing paragraph with multiple lines. Testing
                              paragraph with multiple lines. 
                              3 Testing paragraph with multiple lines. 
                              
                              5 Testing paragraph with multiple lines. Testing paragraph with multiple lines. Testing
                              paragraph with multiple lines. 
                              6 Testing paragraph with multiple lines. 
                              7 Testing paragraph with multiple lines. Testing paragraph with multiple lines.  89 words
                              8 Testing paragraph with multiple lines. Testing paragraph with multiple lines.   90
                              words
                              9 Testing paragraph with multiple lines. Testing paragraph with multiple lines.    91
                              words
                              10 Testing paragraph with multiple lines. Testing paragraph with multiple lines.    92
                              words
                              
                              
                              11 Testing paragraph with multiple lines. Testing paragraph with multiple lines. 89 words
                              
                              
                              
                              12 Testing paragraph with multiple lines. Testing paragraph with multiple lines.  90
                              words
                              
                              
                              
                              13 Testing paragraph with multiple lines. Testing paragraph with multiple lines.   91
                              words
                              
                              
                              
                              14 Testing paragraph with multiple lines. Testing paragraph with multiple lines.    92
                              words
                              
                              
                              
                              
                              a""";
                                  
    String res = makeParagraphAtDepth(paragraph, 30);
    expect( res, expectedResult);
  });

  test('break_line ', () {
    gTextWidth = 120;

    String paragraph =  """
1 Testing paragraph with breaks in lines. Testing paragraph with multiple lines. Testing paragraph with multiple lines. Testing paragraph with multiple lines.
8 Testing paragraph with multiple lines. Testing paragraph with multiple lines.   90 words
9 Testing paragraph with multiple lines. Testing paragraph with multiple lines.    91 words
10 Testing paragraph with multiple lines. Testing paragraph with multiple lines.    92 words""";


String expectedResult = 
"""1 Testing paragraph with breaks in lines. Testing paragraph with multiple lines. Testing
                              paragraph with multiple lines. Testing paragraph with multiple lines.
                              8 Testing paragraph with multiple lines. Testing paragraph with multiple lines.   90
                              words
                              9 Testing paragraph with multiple lines. Testing paragraph with multiple lines.    91
                              words
                              10 Testing paragraph with multiple lines. Testing paragraph with multiple lines.    92
                              words""";
                                  
    String res = makeParagraphAtDepth(paragraph, 30);
    expect( res, expectedResult);
  });


  test('url_break1 ', () {
    gTextWidth = 92;

    //print("\n\nbreak_url_dash test");

    String paragraph =  """
https://github.com/vishalxl/nostr_console/releases/tag/v0.0.7-beta""";


String expectedResult = 
"""https://github.com/vishalxl/nostr_console/releases/tag/v0.0.7-beta""";
                                  
    String res = makeParagraphAtDepth(paragraph, 30);
    //print(res);
    expect( res, expectedResult);
  });


  test('url_break2 ', () {
    gTextWidth = 92;

    //print("123456789|123456789|123456789|123456789|123456789|123456789|123456789|123456789|123456789|");
    List<String> urls = ["https://news.bitcoin.com/former-us-treasury-secretary-larry-summers-compares-ftx-collapse-to-enron-fraud/",
                         "https://chromium.googlesource.com/chromium/src/net/+/259a070267d5966ba5ce4bbeb0a9c17b854f8000",
                         "                                          https://i.imgflip.com/71o242.jpg",
                         " https://twitter.com/diegokolling/status/1594706072622845955?t=LB5Pn51bhj3BhIoke26kGQ&s=19", 
                         "11                    https://github.com/nostr-protocol/nips/blob/master/16.md#ephemeral-events",
                         "https://res.cloudinary.com/eskema/image/upload/v1669030722/306072883_413474904244526_502927779121754777_n.jpg_l6je2d.jpg"];

    for (var url in urls) { 
      String res = makeParagraphAtDepth(url, 30);
      //print(url); print(res);print("");
      expect( res, url);
    }
  });


  test('event_file_read', () async {
      Set<Event> initialEvents = {}; // collect all events here and then create tree out of them


      String inputFilename = 'test_event_file.csv';
      initialEvents = readEventsFromFile(inputFilename);

      int numFilePosts = 0;
      // count events
      for (var element in initialEvents) { element.eventData.kind == 1? numFilePosts++: numFilePosts;}
      print("read $numFilePosts posts from file $inputFilename");
      expect(numFilePosts, 3486, reason:'Verify right number of kind 1 posts');

      Store node = getTree(initialEvents);
      
      expect(0, node.getNumDirectRooms(), reason:'verify correct number of direct chat rooms created');

      int numKind4xChannels = 0;
      for (var channel in node.channels) {
        channel.roomType == enumRoomType.kind40? numKind4xChannels++:1;
      }

      int numTTagChannels = 0;
      for (var channel in node.channels) {
        channel.roomType == enumRoomType.RoomTTag? numTTagChannels++:1;
      }

      int numLocationTagChannels = 0;
      for (var channel in node.channels) {
        channel.roomType == enumRoomType.RoomLocationTag? numLocationTagChannels++:1;
      }

      expect(78, numKind4xChannels, reason: 'verify correct number of public channels created of kind 4x');
      expect(41, numTTagChannels, reason: 'verify correct number of public channels created of T tag type');
      expect(2, numLocationTagChannels, reason: 'verify correct number of public channels created of Location tag');

      expect(3046, node.getNumMessagesInChannel('25e5c82273a271cb1a840d0060391a0bf4965cafeb029d5ab55350b418953fbb'), 
              reason:'verify a public channel has correct number of messages');
      //node.printStoreTrees(0, DateTime.now().subtract(Duration(days: 105)), (a) => true); 28 dec 2022

  });

  test('utils_fns', () async {

    String content1 = '#bitcoin #chatgpt #u-s-a #u_s_a #1947 #1800';
    Set<String>? tags = getTagsFromContent(content1);
    //print(tags);  
    expect(tags?.length, 6);
    expect(tags?.contains("bitcoin"), true);

      String pubkeyQrCodeResult1 = 
  """   █▀▀▀▀▀█ ██▄▄▀ ▄▄     █ ▄▀ █▀▀▀▀▀█
   █ ███ █ █▄█ ██▄   ▄▄ ██▀▀ █ ███ █
   █ ▀▀▀ █  ▀ ▀ █▀▄█▄███  ██ █ ▀▀▀ █
   ▀▀▀▀▀▀▀ ▀ ▀▄█ █▄▀ █ █▄█▄▀ ▀▀▀▀▀▀▀
   █ ▀██▄▀▄▀▄▀ █ ▀ ▀▄█▀██ ▀▄▀▄▄▄█▀▀█
     ▄▄█ ▀▄   ▄▄█ ▀█▀█▀▄ ▄▀▀▄▄▄▀▀▀█▀
    ▄█▄ █▀    █▄ ▀▀▄█▀▀███ ▀▀▄ ▀ ▄▄▄
   ▀  ██▀▀▀ ▀ ▄▄▄ █▀█▄▀   ▄██ ▀▀██▀▀
     ▀█▄▄▀█▄ ▄▀▄▀ ▀  ▄▄▄ █ █▄▄▀▀▀███
   ▄ █▀█▄▀▄▄▄ ▄▀█▄█▀ ▀ ██▀█▀█▄▀█ ▀▄█
   ▄▀▀  ▀▀ █▄▄ ▀▀▄▄▄ ▄▀█▄▄▀   ▄▄ ▄ ▄
   ▄▄▄▀  ▀  ▄█▀█ ▀ ██ █▀█▄ █ ▄▀██ ▀ 
    ▀   ▀▀▀█▀ ▄▄ █  ▀▀ ▀▀▀ █▀▀▀█  █▄
   █▀▀▀▀▀█  ▀█▀▄▄▄▀█▀   ▀▀▀█ ▀ █▄██▄
   █ ███ █ █▄██▀▄▀ ▀▀▀▄▄ ▄▄▀█▀██▄ ██
   █ ▀▀▀ █ ▀█▀▄ ▄█▀███ ▀ ▄   ▀▀▀▄█ ▀
   ▀▀▀▀▀▀▀ ▀▀▀     ▀▀ ▀ ▀▀     ▀  ▀ \n""";

      String profilePubkey1 = "add06b88bd78c5cbb2cd990e873adfba3eaf8e0217d3208be2be770eb506d430";
      expect (pubkeyQrCodeResult1, getPubkeyAsQrString(profilePubkey1), reason: "testing qr code function");

      String lnQrCodeResult1 = """:-\n\n█▀▀▀▀▀█ █▀▄█▄▄█▀ █ ▄▄ ▀▄ ▀  ▀█▀ ▀▄▀ ██  █▀ ▄█▀███ █▀   ▀▄ █▀▀▀▀▀█
█ ███ █ ▄  ▀ ▄▀█▄▄▄▀▀ ▀▀▄▄██▄▄██▄▄█▄▄      ▄▀▄▀ ▀ █████▄▀ █ ███ █
█ ▀▀▀ █  ▀▀█▄█▄▄▀▀▀█▀ ▀  █▄█▄██▀▀▀█ ▄▀▀  ███ █▄▄ ▄▀▀▄█▄ ▀ █ ▀▀▀ █
▀▀▀▀▀▀▀ █ ▀▄█▄▀ ▀ █ █ █ ▀ ▀ ▀▄█ ▀ █ ▀ ▀ █ ▀▄▀ ▀ ▀ █▄█▄▀ ▀ ▀▀▀▀▀▀▀
▄█▀ ██▀█▄▄ █ ▄██▀▀█▄▀▀ ▄ ▄ ██ █▀█▀█▀ █ ▀▀██▄▄█ █▄▀██▀██  ▀█  ▀▄█▀
█▄ ▀██▀ █▀ ▄▄▀▄█▀█▀▀  ▀██▄  █▄█ ▄█▄██ ▀▄█▀ ▀█▀▀▀ █ ▄█ ▄▄█▀█▀▄▄▄▄█
█  ▄ ▄▀ ▄ ▄▀▀█▄▄▀█▀ █▀▀  █▀██▀▀▄▄▄▄▄▄▄▀▀██▄█▀▀█▀█▄██ █ ▄ █ █▀ █▄▄
█▄  ▀▀▀▀██▀▄█ ▄██▀█ █▄█▄▄▄▀   ▀▀▄▀  ▀▀███ ▄█▄▄▄▄▄  ▄   ▄▄  ▀▀▀ ▀▄
▀ ▄  ▄▀██▀▄▀   ▀█  ▀█ ▄▄▄█▀ ▄▀▄  ▄▄ ▄█ ▄▀▄▀▀▀▄▄ ▄▀▄▀▀▄▀▀▄  ▄█ ▄██
▄█▄▀█▄▀ ██▀ █▀█▄▀█▀▄█▄▀▀███▀█▀▀█▀▀▄█▄▄▀▀█▀▀███▀▄███ ▀ ▀▀▀▀▀ ▀█▀▀█
▀  ▀▀▀▀ █ █▀█ ▄▄▄█▀ ▀  █   ▄▀  ▀█▄█▄▄▄█ ▄▀▄█▄ █▀▄▄▀  ▀ ▄█▄▀▄▀▀█▀▄
▄ ▄█▄▄▀▀▀▀ █▀▄▀▀ █▀▀▀▄ ▄▀ █▄▄▀█▄▀▀▀▀ ▀▀▀▄██ ▀█▄▀█▄█  ▄▀▄▀█▀ █    
█▀▄▀▀ ▀▄▄ ▄▄█▄▀▄▄   ▄   ▄▄▄▀ ▄  ▄ █ ▄ ▀▀  █ ▄ █  ▄▄▀ ▄▀ ▄ █▄ ▄█▄ 
▄    ▀▀█▄▀▀██▀ ▀█ ▀ ▄▀▀▀█▀ ▄█▄▀▀▄████▀▄██▄  ▄██▀█▀▀ █ ▀▄ ▀▄▀▀▀ ▄▀
█▄██ █▀▀ ▄▄▄ █▀ █▄▄▀ ▄█▄▄▀ ▄█ ██▄ ▄▀▄█▀▄█ █▄▄▄▄ ▄█▀▀▀ █ ▄▄ ▀▄▀▄▀█
▀▀▄▀█▀▀▀█ ▄▄▄▄▄▄ █▀▄▄ ▀ ▄   ▄▄█▀▀▀█▀▄█▀█▄  ▄▄▄  ▄█▄█▀▀  █▀▀▀██▀▀█
██▀ █ ▀ █  ▄█ ▄██ ▄▀ ▀▀ █  ██ █ ▀ █▀  █▄ ██▄█ ▄▀ ▄▄▄▄▀▄▀█ ▀ ██▄ ▀
█▄▀▀█▀▀█▀ ▀ ▄▀ █▄     ▀▄█▀ ▄▄ ▀▀▀▀▀██ █▀▀██ ▀  ▀█▀█▀ ██ ▀█▀▀█ ▄ ▀
▀▄▄ ▀█▀█▀ ▀██▄▄█▀▀███▄▀█▀▄██▀▀█▀▀▀▄█▀▄ █▀▀█▀█▀▀███▀▀▀▀▀▀█▀▄███ ▀█
▀█▄▀█▄▀ █ ▄▀▀▄▀▄▄█  ▄   █ █ ▀█ ▄▄▄ ▀▄ ▀ ▀█▄ ▄▄▄   ▀ █▀ ▀▄▄▄ █▄█▀ 
█ ▄▄▄ ▀▄▀█▄▀█▀▀█ █ ▄█▄▄▀▀▀▀█▄▄█ ▀ █▀▀▀██ ▄█▄▀▀▄██▀▄█ ▄▀▄▀█▄▀█ ▀█ 
██▄▀▀█▀▄ ▄  █  ▀█ ▄█▄ ▄██   █  ▄ ▄  ▄▄ ▀█  ▄█      ▀▀  ██▄ ▄█▄ ▀▀
█▄█▄██▀▀ ▀▀▄█▀ █▀▀██ ▄█▄▀█▄██▀▄█▄▀█▄▀  ▀█▀██▄ █▄▀▄▄▀▀▀██▄ ▀▄█ ██▀
█▄▀▄ ▀▀▀ ▄▀▄ ▀ ▀ ▄ ▄▀ ▀██▀▄ █ ▄ █▄▀██▀▄ ▄▄ █▀ ▀▄ █▄▀▄▄ █▀ █ ██  █
▄ ▄  █▀█▀▀▄█▀▄▀▀▀███▀ █▀█▄ █▀  ███▀▀▀ ██████▀▀█▀██▀▀█████▄▀▀▀████
▀▀▄▀▀▄▀ █▄   ▄█  ▀▄ ▄ ▄▀  ▀ ██▄ █▄ ▄▄▄█▀▄▀ ▄▄▄▄▀█▄█ ▀█  ▀     ██▄
▀█▄▄▄█▀▄█ ▀▀█▀█▀▄▀█ █▀▄█▀▀ ▀▄█▀▄█ █▀█ ▀▀ ▄  ▀  ▀█▀▀█ ▀▄ ▀▀▄██▀█▀▄
▄ ▀█ ▀▀ ▀   ▀▄ ▄▀   ▀  █▄   ▀  ▀█▄    ▄ █▄▄▄  ▄     █  █▀▄  ▀▄▄▄▄
 ▀▀ ▀ ▀▀▀ ██▄ █▀ ▀▀ █ ▀▄  ██ ██▀▀▀█ ▀ █▄█▀▀▀▀▄ ▀  ▀ ▄▄  █▀▀▀██   
█▀▀▀▀▀█ █ ▀ ██▄▄▄  ▀▄▄██▄█▄   █ ▀ ██▄ ▀▀ █▀▄█▀ ██ ██▀▄█▄█ ▀ █ █ ▀
█ ███ █ ▀▄█▀█▄▀█▀  █▀▀ ▀▀ ▄▀██▀▀███   █ ▄ ▀▄▄▄█▄▄ ▄█  ▄█▀█▀▀▀▀█▀▀
█ ▀▀▀ █ █▀██▄▄▄▄▄  ▄█ ▄█  ▄  ██ █▄▄█  █▄▄▄▄▄█ █▀  █▄  ▀ ▀▄▄█ ▄▀▄▄
▀▀▀▀▀▀▀  ▀  ▀ ▀ ▀▀▀  ▀  ▀ ▀  ▀▀  ▀  ▀ ▀  ▀▀     ▀ ▀ ▀▀▀  ▀ ▀ ▀▀  
\n\n""";

      String lnInvoice1 = "lnbc30n1p3689h4sp54ft7dn46clu4h8lyey2zj2hfvp07e2ekcrmceeq4gxmw9ml2pwuspp5zfup7rmneu47f34qznatwcmkexdkl78ppntms9y8vgj75cyzvh5qdq2f38xy6t5wvxqyjw5qcqpjrzjqvhxqvs0ulx0mf5gp6x2vw047capck4pxqnsjv0gg8a4zaegej6gxzadnsqqj3cqqqqqqqqqqqqqqqqqyg9qyysgqv5cg4cly6sr2q4n0vkfcgmgxd5egdrztt8pn4003thqzr8sn5e8swdxw4g75jr233hyr2p655xgwh98jh3pkn3kranjkg0ysrwze44qpqmeq35";
      expect (expandLNInvoices(lnInvoice1),lnQrCodeResult1,  reason: "testing ln qr code function");

  });

  test( "test_configFile", () async {

    dynamic credentials = await readConfigFile();

    if( credentials != null) {
      String? priKey = credentials["secret_key_bech32"];
      String? pubKey = credentials["public_key_bech32"];
      List<dynamic>? configFileRelays = credentials["relays"]; 

      if( priKey != null) {
        //print("private key = $priKey");
        print("Config file private key found.");
        userPrivateKey = priKey;
      } else {
        print("Config file private key not found.");
      }
    } else {
      print("Credentials not found in config file.");
    }
  
  });


  test('getParent', () {
  
    // "tags":[
    //  ["e","ed05e1ba26c9d3684a4f0f9443dbb45cccb4ba20f2b7b05a6ac1aee0a8324baf","","root"],
    // ["e","ebb01cc8788dadfc4ce621999ec3b332ff712937bacc1be99a20bf01ed29d2b0","","reply"],
    // ["p","20651ab8c2fb1febca56b80deba14630af452bdce64fe8f04a9f5f67e4a3c1cc"]

    Event exampleEvent_31e_daniel = Event.fromJson('["EVENT","latest_live_all",{"content":"Hard to tell the difference these days, ngl.","created_at":1755366333,"id":"31e2ebe59b3fd691450055cbbae2545e41dd986032d564e49a56125da1ddea96","kind":1,"pubkey":"ee6ea13ab9fe5c4a68eaf9b1a34fe014a66b40117c50ee2a614f4cda959b6e74","sig":"7af6c0d86ffa4ccf96c9ffd9c7fe9d87ae77c7be062bbd05079e666129aafd6802023ebf6167291419b06a574e09167694c6fa45bfa585c61f22a122f74856a5","tags":[["e","ed05e1ba26c9d3684a4f0f9443dbb45cccb4ba20f2b7b05a6ac1aee0a8324baf","","root"],["e","ebb01cc8788dadfc4ce621999ec3b332ff712937bacc1be99a20bf01ed29d2b0","","reply"],["p","20651ab8c2fb1febca56b80deba14630af452bdce64fe8f04a9f5f67e4a3c1cc"]]}]', "");

    Store  store     = Store.fromEvents({exampleEvent_31e_daniel});

    //Tree tree = Tree.withoutStore(exampleEvent_31e_daniel,[]);

    String parentId = exampleEvent_31e_daniel.eventData.getParent({});
    print("parentId = $parentId");
    
    expect(parentId, "ebb01cc8788dadfc4ce621999ec3b332ff712937bacc1be99a20bf01ed29d2b0");

  });



  Future.delayed(Duration(milliseconds: 2000), () {
    exit(0);
  });


  return ;

} // end main

