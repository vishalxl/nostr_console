import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';

const int  screenWidth = 120;
const bool enableVerticalLines = false;
const int  spacesPerDepth = 8;
int    keyLenPrinted    = 6;

const int max_depth_allowed      = 7;
const int leftShiftDeepThreadsBy = 3;

//String defaultServerUrl = 'wss://relay.damus.io';
String defaultServerUrl = 'wss://nostr-relay.untethr.me';

// global user names from kind 0 events, mapped from public key to user name
Map<String, String> gKindONames = {}; 

List<String> gBots = [  "3b57518d02e6acfd5eb7198530b2e351e5a52278fb2499d14b66db2b5791c512",  // robosats orderbook
                        "887645fef0ce0c3c1218d2f5d8e6132a19304cdc57cd20281d082f38cfea0072",   // bestofhn
                        "f4161c88558700d23af18d8a6386eb7d7fed769048e1297811dcc34e86858fb2"   // bitcoin_bot
                      ];

int gDebug = 0;

// If given event is kind 0 event, then populates gKindONames with that info
void processKind0Event(Event e) {
  if( e.eventData.kind != 0) {
    return;
  }

  String content = e.eventData.content;
  if( content.isEmpty) {
    return;
  }
  try {
    dynamic json = jsonDecode(content);
    if(json["name"] != Null) {
      gKindONames[e.eventData.pubkey] = json["name"]??"";
    }
  } catch(ex) {
    if( gDebug != 0) print("Warning: In processKind0Event: caught exception for content: ${e.eventData.content}");
  }
}

// returns name by looking up global list gKindONames, which is populated by kind 0 events
String getAuthorName(String pubkey) {
  String max3(String v) => v.length > 3? v.substring(0,3) : v.substring(0, v.length);
  String name = gKindONames[pubkey]??max3(pubkey);
  return name;
}

void printUserInfo(List<Event> events, String pub) {
  int numUserEvents = 0;
  for(int i = 0; i < events.length; i++) {
    if( events[i].eventData.pubkey == pub && events[i].eventData.kind == 1) {
      numUserEvents++;
    }
  }
  print("Number of user events for user ${getAuthorName(pub)} : $numUserEvents");
}

void printDepth(int d) {
  if( d == 0) {
    return;
  }

  for( int i = 0; i < spacesPerDepth * d ; i++) {
    stdout.write(" ");
  }
 }

String rightShiftContent(String s, int numSpaces) {
  String newString = "";
  int    newlineCounter = 0;
  String spacesString = "";

  for( int i = 0; i < numSpaces ; i++) {
    spacesString += " ";
  }

  for(int i = 0; i < s.length; i++) {
    if( s[i] == '\n') {
      newString += "\n";
      newString += spacesString;
      newlineCounter = 0;
    } else {
      if( newlineCounter >= (screenWidth - numSpaces)) {
        newString += "\n";
        newString += spacesString;
        newlineCounter = 0;
      } 
      newString += s[i];
    }
    newlineCounter++;
  }
  return newString;
}

class Contact {
  String id, relay, name;
  Contact(this.id, this.relay, this.name);
  factory Contact.fromJson(dynamic json) {
    return Contact(json[1] as String, json[2] as String, json[3]);
  }
}

class EventData {
  String id;
  String pubkey;
  int    createdAt;
  int    kind;
  String content;
  List<String> eTagsRest;// rest of e tags
  List<String> pTags;// list of p tags for kind:1
  List<List<String>> tags;

  List<Contact> contactList = []; // used for kind:3 events, which is contact list event
  
  String getParent() {
    if( eTagsRest.isNotEmpty) {
      return eTagsRest[eTagsRest.length - 1];
    }
    return "";
  }

  EventData(this.id, this.pubkey, this.createdAt, this.kind, this.content, this.eTagsRest, this.pTags, this.contactList, this.tags);
  
  factory EventData.fromJson(dynamic json) {
    List<Contact> contactList = [];

    List<String> eTagsRead = [];
    List<String> pTagsRead = [];
    List<List<String>> tagsRead = [];

    var jsonTags = json['tags'];      
    var numTags = jsonTags.length;
        
    // NIP 02: if the event is a contact list type, then populate contactList
    if(json['kind'] == 3) {
      for( int i = 0; i < numTags; i++) {
        var tag = jsonTags[i];
        var n = tag.length;
        String server = defaultServerUrl;
        if( n >=3 ) {
          server = tag[2].toString();
          if( server == 'wss://nostr.rocks') {
            server = defaultServerUrl;
          }
        }
        Contact c = Contact(tag[1] as String, server, 3.toString());
        contactList.add(c);
      }
    } else {
      if ( json['kind'] == 1) {
        for( int i = 0; i < numTags; i++) {
          var tag = jsonTags[i];
          //stdout.write(tag);
          //print(tag.runtimeType);
          if( tag.isEmpty) {
            continue;
          }
          if( tag[0] == "e") {
            eTagsRead.add(tag[1]);
          } else {
            if( tag[0] == "p") {
              pTagsRead.add(tag[1]);
            }
          }
          List<String> t = [];
          t.add(tag[0]);
          t.add(tag[1]);
          tagsRead.add(t);

          // TODO add other tags
        }
      }
    }

    if(gDebug != 0) {
      print("Creating EventData with content: ${json['content']}");
    }

    return EventData(json['id'] as String,      json['pubkey'] as String, 
                     json['created_at'] as int, json['kind'] as int,
                     json['content'] as String, eTagsRead,        pTagsRead,
                     contactList,               tagsRead);
  }

  String expandMentions(String content) {
    if( tags.isEmpty) {
      return content;
    }

    List<String> placeHolders = ["#[0]", "#[1]", "#[2]", "#[3]", "#[4]", "#[5]" ];
    for(int i = 0; i < placeHolders.length; i++) {
      int index = -1;
      Pattern p = placeHolders[i];
      if( (index = content.indexOf(p)) != -1 ) {
        if( i >= tags.length) {
          continue;
        }

        if( tags[i].isEmpty || tags[i].length < 2) {
          continue;
        }
        String author = getAuthorName(tags[i][1]);

        //print("\n\nauthor mention: i = $i  index = $index  tags[i][1] = ${tags[i][1]} author = $author");
        //print("tags = $tags");

        //print("in expandMentions: changing content at index i = $i");
        content = "${content.substring(0, index)} @$author${content.substring(index + 4)}";
      }
    }
    return content;
  }


  void printEventData(int depth) {
    int n = 5;
    String maxN(String v)       => v.length > n? v.substring(0,n) : v.substring(0, v.length);
    void   printGreen(String s) => stdout.supportsAnsiEscapes ?stdout.write("\x1B[32m$s\x1B[0m"):stdout.write(s);

    DateTime dTime = DateTime.fromMillisecondsSinceEpoch(createdAt *1000);
    
   // TODO do it in one call
   final df1 = DateFormat('hh:mm a');
   final df2 = DateFormat(DateFormat.YEAR_ABBR_MONTH_DAY);
   String strDate = df1.format(DateTime.fromMillisecondsSinceEpoch(createdAt*1000));
   strDate += " ${df2.format(DateTime.fromMillisecondsSinceEpoch(createdAt*1000))}";
    if( createdAt == 0) {
      print("debug: createdAt == 0 for event $content");
    }

    content = expandMentions(content);
    String contentShifted = rightShiftContent(content, spacesPerDepth * depth + 10);
    
    printDepth(depth);
    stdout.write("+-------+\n");
    printDepth(depth);
    String name = getAuthorName(pubkey);
    stdout.write("|Author : $name     id: ${maxN(id)}      Time: $strDate\n");
    printDepth(depth);
    stdout.write("|Message: ");
    printGreen(contentShifted);
  }

  @override
  String toString() {
    if( id == "non") {
      return '';
    }

    String max3(String v) => v.length > 3? v.substring(0,3) : v.substring(0, v.length);
    DateTime dTime = DateTime.fromMillisecondsSinceEpoch(createdAt *1000);
    if( createdAt == 0) {
      print("createdAt == 0 for event $content");
    }
    return '\n-------+-------------\nAuthor : ${max3(pubkey)}\nMessage: $content\n\nid     : ${max3(id)}     Time: $dTime     Kind: $kind';
  }
}

class Event {
  String event;
  String id;
  EventData eventData;
  String originalJson;
  List<String> seenOnRelays;

  Event(this.event, this.id, this.eventData, this.seenOnRelays, this.originalJson);

  factory Event.fromJson(String d, String relay) {
    dynamic json = jsonDecode(d);
    if( json.length < 3) {
      String e = "";
      e = json.length > 1? json[0]: "";
      return Event(e,"",EventData("non","", 0, 0, "", [], [], [], [[]]), [relay], "[json]");
    }
    return Event(json[0] as String, json[1] as String,  EventData.fromJson(json[2]), [relay], d );
  }

  void printEvent(int depth) {
    eventData.printEventData(depth);
    //stdout.write("\n$originalJson \n");
  }

  @override 
  String toString() {
    return '$eventData     Seen on: ${seenOnRelays[0]}\n';
  }
}

class Tree {
  Event             e;
  List<Tree>        children;
  Map<String, Tree> allEvents;
  Tree(this.e, this.children, this.allEvents);

  // @method create top level Tree from events. 
  // first create a map. then process each element in the map by adding it to its parent ( if its a child tree)
  factory Tree.fromEvents(List<Event> events) {
    if( events.isEmpty) {
      return Tree(Event("","",EventData("non","", 0, 0, "", [], [], [], [[]]), [""], "[json]"), [], {});
    }

    // create a map from list of events, key is eventId and value is event itself
    Map<String, Tree> mAllEvents = {};
    events.forEach((element) { mAllEvents[element.eventData.id] = Tree(element, [], {}); });

    mAllEvents.forEach((key, value) {

      if(value.e.eventData.eTagsRest.isNotEmpty ) {
        // is not a parent, find its parent and then add this element to that parent Tree
        //stdout.write("added to parent a child\n");
        String id = key;
        String parentId = value.e.eventData.getParent();
        mAllEvents[parentId]?.addChildNode(value);
      }
    });

    // add parent trees as top level child trees of this tree
    List<Tree>  topLevelTrees = [];
    for( var value in mAllEvents.values) {
        if( !value.e.eventData.eTagsRest.isNotEmpty) {  // if its a parent
            topLevelTrees.add(value);
        }
    }

    return Tree( events[0], topLevelTrees, mAllEvents); // TODO remove events[0]
  } // end fromEvents()

  bool insertEvents(List<Event> newEvents) {
    //print("In insertEvents num events: ${newEvents.length}");
    List<String> newEventsId = [];
    newEvents.forEach((element) { 
      if( allEvents[element.eventData.id] != null) {
        return; // don't process if the event is already present in the map
      }
      if( element.eventData.kind != 1) {
        return; // only kind 1 events are added to the tree
      }
      allEvents[element.eventData.id] = Tree(element, [], {}); 
      newEventsId.add(element.eventData.id);
    });

    //print("In insertEvents num eventsId: ${newEventsId.length}");
    newEventsId.forEach((newId) {

      Tree? t = allEvents[newId];
      if( t != null) {
        if( t.e.eventData.eTagsRest.isEmpty) {
          // is a parent event
            children.add(t);
        } else {
              String parentId = t.e.eventData.getParent();
              allEvents[parentId]?.addChildNode(t);
        }
      }
    });

    return true;
  }

  void addChild(Event child) {
    Tree node;
    node = Tree(child, [], {});
    children.add(node);
  }

  void addChildNode(Tree node) {
    children.add(node);
  }

  void printTree(int depth, bool onlyPrintChildren, var newerThan) {

    children.sort(ascendingTimeTree);
    if( !onlyPrintChildren) {
      e.printEvent(depth);
    } else {
      depth = depth - 1;
    }

    for( int i = 0; i < children.length; i++) {
      if(!onlyPrintChildren) {
        stdout.write("\n");  
        printDepth(depth+1);
        stdout.write("|\n");
      } else {

        DateTime dTime = DateTime.fromMillisecondsSinceEpoch(children[i].e.eventData.createdAt *1000);
        //print("comparing $newerThan with $dTime");
        if( dTime.compareTo(newerThan) < 0) {
          continue;
        }
        stdout.write("\n");  
        printDepth(depth+1);
        stdout.write("\n\n\n");
      }

      // if the thread becomes too 'deep' then reset its depth, so that its 
      // children will not be displayed too much the right, but are shifted
      // left by about <leftShiftDeepThreadsBy> places
      if( depth > max_depth_allowed) {
        depth = max_depth_allowed - leftShiftDeepThreadsBy;
        printDepth(depth+1);
        stdout.write("+-------------------------------+\n");
        
      }
      children[i].printTree(depth+1, false, newerThan);
    }
  }

  String getTagsFromEvent(String replyToId) {

    String strTags = "";
    if( replyToId == "") {
      return strTags;
    }
    for(  String k in allEvents.keys) {
      if( k.substring(0, replyToId.length) == replyToId) {
        strTags =  '["e","$k"]';
        break;
      }
    }
    return strTags;
  }
 
}

List<String> getpTags(List<Event> events) {
  List<String> pTags = [];
  for(int i = 0; i < events.length; i++) {
    pTags.addAll(events[i].eventData.pTags);
  }

  // remove duplicate pTags events
  Set tempPtags = {};
  pTags.retainWhere((x) => tempPtags.add(x));

  return pTags;
}

int ascendingTime(Event a, Event b) {
  if(a.eventData.createdAt < b.eventData.createdAt) {
    return 0;
  }
  return 1;
}

int ascendingTimeTree(Tree a, Tree b) {
  if(a.e.eventData.createdAt < b.e.eventData.createdAt) {
    return 0;
  }
  return 1;
}

void printEvents(List<Event> events) {
    events.sort(ascendingTime);
    for( int i = 0; i < events.length; i++) {
      if( events[i].eventData.kind == 1) {
        print('${events[i]}');
      }
    }
}

Tree getTree(events) {
    if( events.length == 0) {
      print("Warning: In printEventsAsTree: events length = 0");
      return Tree(Event("","",EventData("non","", 0, 0, "", [], [], [], [[]]), [""], "[json]"), [], {});
    }

    // populate the global with display names which can be later used by Event print
    events.forEach( (x) => processKind0Event(x));

    // remove all events other than kind 1 ( posts)
    events.removeWhere( (item) => item.eventData.kind != 1 );  

    // remove bot events
    events.removeWhere( (item) => gBots.contains(item.eventData.pubkey));

    // remove duplicate events
    Set ids = {};
    events.retainWhere((x) => ids.add(x.eventData.id));

    // create tree from events
    Tree node = Tree.fromEvents(events);

    return node;
}

/* 
kind 0 event
{
  "id": "63de3e2fe397fedef9d8f1937e8c7f73727bd6410d2e7578eb348d4ee059feaf",
  "pubkey": "004db7605cfeba09b15625deb77c9369029f370591d68231b7c4dfd43f8f6f4f",
  "created_at": 1659944329,
  "kind": 0,
  "tags": [],
  "content": "{\"name\":\"IrredeemablePussy@minds.com\",\"about\":\"\",\"picture\":\"https://www.minds.com/icon/742483671239368719/medium/1502397901/1659944329/1659944329\"}",
  "sig": "c500f7f8e27c3d1a41ed196931f66253cdd42dbb1e53b15fd1916da5c261b4d0e06d0008b39016775b3be56e6397c8d747d98174106f04c5874650fbe9d930b0"
}


reply/root example for e tag
{
  "id": "4019debf44a087b973b7d8776e7ce74ee84a15e9c3dbed0b60dfdec23d170911",
  "pubkey": "2ef93f01cd2493e04235a6b87b10d3c4a74e2a7eb7c3caf168268f6af73314b5",
  "created_at": 1659210144,
  "kind": 1,
  "tags": [
    [
      "e",
      "0ddebf828647920417deb00cc9de70a83db5b5c414466f684a5cbe7f02723243",
      "",
      "root"
    ],
    [
      "e",
      "f68f0299f3a3204638337e6f7edf1a6653066a8d8a2bc74c4ab6ebe92a9c4130",
      "",
      "reply"
    ],
*/


/*  
NIP 02
{
  "kind": 3,
  "tags": [
    ["p", "91cf9..4e5ca", "wss://alicerelay.com/", "alice"],
    ["p", "14aeb..8dad4", "wss://bobrelay.com/nostr", "bob"],
    ["p", "612ae..e610f", "ws://carolrelay.com/ws", "carol"]
  ],
  "content": "",
  ...other fields


Example Event returned
[
  "EVENT",
  "latest",
  {
    "id": "5e4ca472540c567ba877ab232fa77c0801f4b2121756ed21d827e749b5074ac7",
    "pubkey": "47bae3a008414e24b4d91c8c170f7fce777dedc6780a462d010761dca6482327",
    "created_at": 1657316002,
    "kind": 1,
    "tags": [
      [
        "p",
        "80482e60178c2ce996da6d67577f56a2b2c47ccb1c84c81f2b7960637cb71b78",
        "wss://relay.damus.io"
      ],
      [
        "e",
        "241f1108b3616eb4b3cfb9fdbab29d7f8d291fda9db84a79f2491271e2f6122e"
      ],
      [
        "e",
        "b3349c4de2ff7a672c564e6fd147bc2d5dd71b525f96f35f8ede75138136c867",
        "wss://nostr-pub.wellorder.net"
      ]
    ],
    "content": "Not even surprised it's a thing https://coinmarketcap.com/currencies/lol/",
    "sig": "abebbc96a8a922f06ca2773c59521d03b6a8dd5597ae5654afc2d49e03a1e9c193729ff60473f837edc526e41c94f3de8a328c20bf9cff5353cb9c409a982461"
  }
]


  factory EventData.fromStr(String str) {
    var json = jsonDecode(str);
    return EventData(json['id'] as String, json['pubkey'] as String, json['content'] as String);
  }
 */