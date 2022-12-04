  import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/settings.dart';
import 'package:nostr_console/utils.dart';
import 'package:test/test.dart';
import 'package:nostr_console/tree_ds.dart';


EventData exampleEdata = EventData("id1", "pubkey",  1111111, 1, "content", [], [], [], [[]], {});
EventData exampleEdataChild = EventData("id2", "pubkey", 1111111, 1, "content child", [], [], [], [[]], {});

Event exampleEvent = Event('event', 'id3', exampleEdata, ['relay name'], "[json]");
Event exampleEventChild = Event('event', 'id4', exampleEdataChild, ['relay name'], "[json]");

Store exampleStore = Store([], {}, [], [], [], [], {});
Tree  exampleTree  = Tree.withoutStore(exampleEvent, []);

//bool skipTest = true;

void main() {
  
  test('PrintEmptyEvent', () {
    //expect(EventData("non","",1,1,"", [], [], [], [[]], {}).toString(), "");
  });

  test('printEventNode', () {
    Store  store     = exampleStore;
    Tree  tree       = exampleTree;
    Tree  treeChild  = Tree.withoutStore(exampleEvent, []);

    tree.setStore(store);
    treeChild.setStore(store);

    tree.children.add(treeChild);
  
    store.printTree(0, DateTime.now().subtract(Duration(days:1)), selectorTrees_all);
  });

  

  test('createNodeTree_ordered', () {
    
    Event exampleEvent1 = Event.fromJson('["EVENT","latest",{"id":"167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722388,"kind":1,"tags":[],"content":"nostr is not federated is it? this is like a global feed of all nostr freaks?","sig":"6db0b287015d9529dfbacef91561cb4e32afd6968edd8454867b8482bde01452e17b6f3de69bffcb2d9deba2a52d3c9ff82e04f7b18eb32428daf7eab5fd27c5"}]', "");
    Event exampleEvent2 = Event.fromJson('["EVENT","latest",{"id":"f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722463,"kind":1,"tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de"]],"content":"I don’t get the technical stuff about relays and things","sig":"9f68031687214a24862226f291e3baadd956dc14ba9c5c552f8c881a40aacd34feda667ef4e4b09711cd43950eec2d272d5b11bd7636de5f457f38f31eaff398"}]', "");
    Event exampleEvent3 = Event.fromJson('["EVENT","latest",{"id":"dfc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722537,"kind":1,"tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de"],["e","f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67"]],"content":"different clients make sense to me. I can use different clients to access nostr but is just one giant soup like twitter","sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]', "");

    Set<Event> listEvents = {exampleEvent1, exampleEvent2, exampleEvent3};

    Store node = Store.fromEvents(listEvents);
    //node.printTree(0, DateTime.now().subtract(Duration(days:1000)), selectorShowAllTrees);
    //print("=========================");
  });

  test('createNodeTree_unordered1', () {
/**
▄────────────
█         137: nostr is not federated is it? this is like a global feed of all nostr freaks?
                                                                    |id: 1670 , 11:29 PM Aug 5

                137: I don’t get the technical stuff about relays and things
                                                                    |id: f3a2 , 11:31 PM Aug 5

                      137: different clients make sense to me. I can use different clients to
                           access nostr but is just one giant soup like twitter
                                                                    |id: dfc5 , 11:32 PM Aug 5
                                                                                                █
                                                                                    ────────────▀
 *  */    

    Event exampleEvent1 = Event.fromJson('["EVENT","latest",{"id":"167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722388,"kind":1,"tags":[],"content":"nostr is not federated is it? this is like a global feed of all nostr freaks?","sig":"6db0b287015d9529dfbacef91561cb4e32afd6968edd8454867b8482bde01452e17b6f3de69bffcb2d9deba2a52d3c9ff82e04f7b18eb32428daf7eab5fd27c5"}]', "");
    Event exampleEvent2 = Event.fromJson('["EVENT","latest",{"id":"f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722463,"kind":1,"tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de"]],"content":"I don’t get the technical stuff about relays and things","sig":"9f68031687214a24862226f291e3baadd956dc14ba9c5c552f8c881a40aacd34feda667ef4e4b09711cd43950eec2d272d5b11bd7636de5f457f38f31eaff398"}]', "");
    Event exampleEvent3 = Event.fromJson('["EVENT","latest",{"id":"dfc5765da281c0ad99cb8693fc98c87f0f86ad56042a414f06f19d41c1315fc3","pubkey":"137d948a0eee45e6cd113faaad934fcf17a97de2236c655b70650d4252daa9d3","created_at":1659722537,"kind":1,"tags":[["e","167063f491c41b7b8f79bc74f318e8a8b0a802bf8364b8bb7d19c887d59ec5de"],["e","f3a267ecbb631012da618de620bc1fe265f6429f412359bf02330b437cf88e67"]],"content":"different clients make sense to me. I can use different clients to access nostr but is just one giant soup like twitter","sig":"d4fdc288e3cb95fc5ab46177fc0982d2aaa3b028eef6649f8200500da9c2e9a16c7a0462638afef7635bfea3094ec10901de759a48e362b60cb08f7e6585e02f"}]', "");

    Set<Event> listEvents = { exampleEvent3, exampleEvent2,  exampleEvent1};

    Store node = Store.fromEvents(listEvents);
    expect(node.topPosts.length, 1);
    expect ( node.topPosts[0].children.length, 1);
    expect ( node.topPosts[0].children[0].children.length, 1);

    //node.printTree(0, DateTime.now().subtract(Duration(days:1000)), selectorTrees_all); // will test for ~1000 days
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
   /* stdout.write(getNumSpaces(30));
    stdout.write("\n");
    stdout.write(getNumDashes(30));
    //stdout.write(getNumSpaces(30)); */
    //stdout.write(res); 

    //return res == expectedResult;;
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
    /*stdout.write(getNumSpaces(30));
    stdout.write("\n");
    stdout.write(getNumDashes(30));
    stdout.write(getNumSpaces(30));
    stdout.write(res); */

/*
    print("paragraph length = ${paragraph.length} res length = ${res.length}");
    print("paragraph last: ${paragraph.substring(paragraph.length - 4, paragraph.length)}");
    print( res.substring(res.length - 100, res.length).codeUnits);
    //res = res.trim();
    print("res trimmed len = ${res.length}");
*/
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

    urls.forEach((url) { 
      String res = makeParagraphAtDepth(url, 30);
      //print(url); print(res);print("");
      expect( res, url);
    });
  });


  test('event_file_read', () async {
      Set<Event> initialEvents = {}; // collect all events here and then create tree out of them


      String input_filename = 'test_event_file.csv';
      initialEvents = await readEventsFromFile(input_filename);

      int numFilePosts = 0;
      // count events
      initialEvents.forEach((element) { element.eventData.kind == 1? numFilePosts++: numFilePosts;});
      //print("read $numFilePosts posts from file $gEventsFilename");
      expect(numFilePosts, 3486, reason:'Verify right number of kind 1 posts');
      

      Store node = await getTree(initialEvents);
      
      expect(0, node.getNumDirectRooms(), reason:'verify correct number of direct chat rooms created');
      expect(80, node.getNumChannels(), reason: 'verify correct number of public channels created');

      expect(3046, node.getNumMessagesInChannel('25e5c82273a271cb1a840d0060391a0bf4965cafeb029d5ab55350b418953fbb'), 
              reason:'verify a public channel has correct number of messages');

      String qrCodeResult1 = 
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
      expect (qrCodeResult1, getQrCodeAsString(profilePubkey1), reason: "testing qr code function");
  });

  return ;
} // end main


