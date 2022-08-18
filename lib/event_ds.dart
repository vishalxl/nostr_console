import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';

const int  gMinValidScreenWidth = 60;
const int  defaultScreenWidth = 80;
int        screenWidth = defaultScreenWidth;
const int  spacesPerDepth = 8;
int        gNumLeftMarginSpaces = 0; // this number is modified in main 
String     gAlignment = "center"; // is modified in main if --align argument is given

const int maxDepthAllowed      = 4;
const int leftShiftThreadsBy = 2;

// 33 yellow, 31 red, 34 blue, 35 magenta. Add 60 for bright versions. 
const String commentColor = "\x1B[32m"; // green
const String notificationColor = "\x1b[36m"; // cyan
const String warningColor = "\x1B[31m"; // red
const String colorEndMarker = "\x1B[0m";

//String defaultServerUrl = 'wss://relay.damus.io';
String defaultServerUrl = 'wss://nostr-relay.untethr.me';

// global user names from kind 0 events, mapped from public key to user name
Map<String, String> gKindONames = {}; 

List<String> gBots = [  "3b57518d02e6acfd5eb7198530b2e351e5a52278fb2499d14b66db2b5791c512",  // robosats orderbook
                        "887645fef0ce0c3c1218d2f5d8e6132a19304cdc57cd20281d082f38cfea0072",   // bestofhn
                        "f4161c88558700d23af18d8a6386eb7d7fed769048e1297811dcc34e86858fb2"   // bitcoin_bot
                      ];

int gDebug = 0;

void printDepth(int d) {
  for( int i = 0; i < spacesPerDepth * d + gNumLeftMarginSpaces; i++) {
    stdout.write(" ");
  }
}

String getNumSpaces(int num) {
  String s = "";
  for( int i = 0; i < num; i++) {
    s += " ";
  }
  return s;
}

String getNumDashes(int num) {
  String s = "";
  for( int i = 0; i < num; i++) {
    s += "-";
  }
  return s;
}


String rightShiftContent(String s, int numSpaces) {
  String newString = "";
  int    newlineCounter = 0;
  String spacesString = getNumSpaces(numSpaces + gNumLeftMarginSpaces);

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
  bool   isNotification; // whether its to be highlighted using highlight color

  List<Contact> contactList = []; // used for kind:3 events, which is contact list event
  
  String getParent() {
    if( eTagsRest.isNotEmpty) {
      return eTagsRest[eTagsRest.length - 1];
    }
    return "";
  }

  EventData(this.id, this.pubkey, this.createdAt, this.kind, this.content, this.eTagsRest, this.pTags, this.contactList, this.tags, {this.isNotification = false});
  
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
    int n = 3;
    String maxN(String v)       => v.length > n? v.substring(0,n) : v.substring(0, v.length);
    void   printGreen(String s, String commentColor) => stdout.supportsAnsiEscapes ?stdout.write("$commentColor$s$colorEndMarker"):stdout.write(s);

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
    stdout.write("|Author : $name  id: ${maxN(id)}  Time: $strDate\n");
    printDepth(depth);
    stdout.write("|Message: ");
    if( isNotification) {
      printGreen(contentShifted, notificationColor);
      isNotification = false;
    } else {
      printGreen(contentShifted, commentColor);
    }
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

void printEvents(List<Event> events) {
    events.sort(ascendingTime);
    for( int i = 0; i < events.length; i++) {
      if( events[i].eventData.kind == 1) {
        print('${events[i]}');
      }
    }
}

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
