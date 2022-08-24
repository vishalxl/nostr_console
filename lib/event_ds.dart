import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:translator/translator.dart';
import 'package:crypto/crypto.dart';
import 'package:nostr_console/settings.dart';


// global contact list of each user, including of the logged in user.
// maps from pubkey of a user, to the latest contact list of that user, which is the latest kind 3 message
// is updated as kind 3 events are received 
Map< String, List<Contact>> gContactLists = {};

final translator = GoogleTranslator();
const int gNumTranslateDays = 4;// translate for this number of days
bool gTranslate = false; // translate flag

int gDebug = 0;

void printDepth(int d) {
  for( int i = 0; i < gSpacesPerDepth * d + gNumLeftMarginSpaces; i++) {
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
      if( newlineCounter >= (gTextWidth - numSpaces)) {
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

bool nonEnglish(String str) {
  bool result = false;
  return result;
}

bool isNumeric(String s) {
 return double.tryParse(s) != null;
}

extension StringX on String {
  isLatinAlphabet({caseSensitive = false}) {
    if( length < 6) { // since smaller words can be smileys can should not be translated
      return true;
    }

    int countLatinletters = 0;
    for (int i = 0; i < length; i++) {
      final target = caseSensitive ? this[i] : this[i].toLowerCase();
      if ( (target.codeUnitAt(0) > 96 && target.codeUnitAt(0) < 123)  || ( isNumeric(target) )) {
        countLatinletters++; 
      }

    }

    if( gDebug > 0) print("in isLatinAlphabet: latin letters: $countLatinletters and total = $length ");
    if( countLatinletters < ( 40.0/100 ) * length ) {
      return false;
    } else {
      return true;
    }
  }
}    


// The contact only stores id and relay of contact. The actual name is stored in a global variable/map
class Contact {
  String id, relay;
  Contact(this.id, this.relay);

  @override 
  String toString() {
    return 'id: $id ( ${getAuthorName(id)})     relay: $relay';
  }
}

String addEscapeChars(String str) {
  return str.replaceAll("\"", "\\\"");
}

String getShaId(String pubkey, int createdAt, String kind, String strTags, String content) {
  String buf = '[0,"$pubkey",$createdAt,$kind,[$strTags],"$content"]';
  if( gDebug > 0) print("In getShaId: for buf = $buf");
  var bufInBytes = utf8.encode(buf);
  var value = sha256.convert(bufInBytes);
  String id = value.toString();  
  return id;
}

class EventData {
  String             id;
  String             pubkey;
  int                createdAt;
  int                kind;
  String             content;
  List<String>       eTagsRest;// rest of e tags
  List<String>       pTags;// list of p tags for kind:1
  List<List<String>> tags;
  bool               isNotification; // whether its to be highlighted using highlight color
  String             evaluatedContent; // content which has mentions expanded, and which has been translated
  Set<String>        newLikes;    //

  List<Contact> contactList = []; // used for kind:3 events, which is contact list event
  
  String getParent() {
    if( eTagsRest.isNotEmpty) {
      return eTagsRest[eTagsRest.length - 1];
    }
    return "";
  }

  EventData(this.id, this.pubkey, this.createdAt, this.kind, this.content, this.eTagsRest, this.pTags,
            this.contactList, this.tags, this.newLikes, {this.isNotification = false, this.evaluatedContent = ""});
  
  factory EventData.fromJson(dynamic json) {
    List<Contact> contactList = [];

    List<String>       eTagsRead = [];
    List<String>       pTagsRead = [];
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
          if( server == 'wss://nostr.rocks' || server == "wss://nostr.bitcoiner.social") {
            server = defaultServerUrl;
          }
          //server = defaultServerUrl;
        }
        Contact c = Contact(tag[1] as String, server);
        
        contactList.add(c);
      }
    } else {
      if ( json['kind'] == 1 || json['kind'] == 7 || json['kind'] == 42 ) {
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

    if(gDebug >= 2 ) {
      print("----------------------------------------Creating EventData with content: ${json['content']}");
    }

    String checkEventId = "078e89dcd3c2bde3d26648fae73411aafced5f3096c4d292169affab747276a8";
    if( json['id'] == checkEventId) {
      if(gDebug > 0) print("got message: $checkEventId");
    }

    return EventData(json['id'] as String,      json['pubkey'] as String, 
                     json['created_at'] as int, json['kind'] as int,
                     json['content'].trim() as String, 
                     eTagsRead,                 pTagsRead,
                     contactList,               tagsRead, 
                     {});
  }

  String expandMentions(String content) {
    if( tags.isEmpty) {
      return content;
    }

    // just check if there is any square bracket in comment, if not we return
    String squareBracketStart = "[", squareBracketEnd = "]";
    if( !content.contains(squareBracketStart) || !content.contains(squareBracketEnd) ) {
      return content;
    }

    // replace the patterns
    List<String> placeHolders = ["#[0]", "#[1]", "#[2]", "#[3]", "#[4]", "#[5]", "#[6]", "#[7]" ];
    for(int i = 0; i < placeHolders.length; i++) {
      int     index = -1;
      Pattern p     = placeHolders[i];
      if( (index = content.indexOf(p)) != -1 ) {
        if( i >= tags.length) {
          continue;
        }

        if( tags[i].isEmpty || tags[i].length < 2) {
          continue;
        }

        String author = getAuthorName(tags[i][1]);
        content = "${content.substring(0, index)} @$author${content.substring(index + 4)}";
      }
    }
    return content;
  }

  void translateAndExpandMentions() {
    if (content == "") {
      return;
    }

    if( evaluatedContent == "") {
      evaluatedContent = expandMentions(content);
      if( gTranslate && !evaluatedContent.isLatinAlphabet()) {
        if( gDebug > 0) print("found that this comment is non-English: $evaluatedContent");
        //final input = "Здравствуйте. Ты в порядке?";

        // Using the Future API
        if( DateTime.fromMillisecondsSinceEpoch(createdAt *1000).compareTo( DateTime.now().subtract(Duration(days:gNumTranslateDays)) ) > 0 ) {
          if( gDebug > 0) print("Sending google request: translating $content");
          try {
          translator
              .translate(content, to: 'en')
              .catchError( (error, stackTrace) =>   null )
              .then( (result) => { evaluatedContent =   "$evaluatedContent\n\nTranslation: ${result.toString()}" , if( gDebug > 0)  print("Google translate returned successfully for one call.")} 
                     );
          } on Exception catch(err) {
            if( gDebug >= 0) print("Info: Error in trying to use google translate: $err");
          }
        }
      }
    }
  }

  // only applicable for kind 42 event
  String getChatRoomId() {
    if( kind != 42) {
      return "";
    }
    return getParent();
  }

  // prints event data in the format that allows it to be shown in tree form by the Tree class
  void printEventData(int depth) {
    int n = 3;
    String maxN(String v)       => v.length > n? v.substring(0,n) : v.substring(0, v.length);
    void   printInColor(String s, String commentColor) => stdout.supportsAnsiEscapes ?stdout.write("$commentColor$s$colorEndMarker"):stdout.write(s);

    DateTime dTime = DateTime.fromMillisecondsSinceEpoch(createdAt *1000);
    
   // TODO do it in one call
   final df1 = DateFormat('hh:mm a');
   final df2 = DateFormat(DateFormat.YEAR_ABBR_MONTH_DAY);
   String strDate = df1.format(DateTime.fromMillisecondsSinceEpoch(createdAt*1000));
   strDate += " ${df2.format(DateTime.fromMillisecondsSinceEpoch(createdAt*1000))}";
    if( createdAt == 0) {
      print("debug: createdAt == 0 for event $content");
    }
   
    String contentShifted = rightShiftContent(evaluatedContent==""?content: evaluatedContent, gSpacesPerDepth * depth + 10);
    
    printDepth(depth);
    stdout.write("+-------+\n");
    printDepth(depth);
    String name = getAuthorName(pubkey);
    stdout.write("|Author : $name  id: ${maxN(id)}  Time: $strDate\n");
    printReaction(depth);    // only prints if there are any likes/reactions
    printDepth(depth);
    stdout.write("|Message: ");
    if( isNotification) {
      printInColor(contentShifted, notificationColor);
      isNotification = false;
    } else {
      printInColor(contentShifted, commentColor);
    }
  }

  // looks up global map of reactions, if this event has any reactions, and then prints the reactions
  // in appropriate color( in case one is a notification, which is stored in member variable)
  void printReaction(int depth) {
    if( gReactions.containsKey(id)) {
      String reactorNames = "|Likes  : ";
      printDepth(depth);
      //print("All Likes:");
      int numReactions = gReactions[id]?.length??0;
      List<List<String>> reactors = gReactions[id]??[];
      for( int i = 0; i <numReactions; i++) {
        String reactorId = reactors[i][0];
        if( newLikes.contains(reactorId)) {
          // colorify
          reactorNames += notificationColor + getAuthorName(reactorId) + colorEndMarker;
        } else {
          reactorNames += getAuthorName(reactorId);
        }
        
        if( i < numReactions -1) {
          reactorNames += ", ";
        }
      }
      print(reactorNames);
      newLikes.clear();
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

// This is mostly a placeholder for EventData. TODO combine both?
class Event {
  String event;
  String id;
  EventData eventData;
  String originalJson;
  List<String> seenOnRelays;

  Event(this.event, this.id, this.eventData, this.seenOnRelays, this.originalJson);

  factory Event.fromJson(String d, String relay) {
    try {
      dynamic json = jsonDecode(d);
      if( json.length < 3) {
        String e = "";
        e = json.length > 1? json[0]: "";
        return Event(e,"",EventData("non","", 0, 0, "", [], [], [], [[]], {}), [relay], "[json]");
      }
      return Event(json[0] as String, json[1] as String,  EventData.fromJson(json[2]), [relay], d );
    } on Exception catch(e) {
      return Event("","",EventData("non","", 0, 0, "", [], [], [], [[]], {}), [relay], "[json]");
    }
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

class ChatRoom {
  String       chatRoomId; // id of the kind 40 start event
  String       name; 
  String       about;
  String       picture;
  List<String> messageIds;  // all the 42 kind events in this

  ChatRoom(this.chatRoomId, this.name, this.about, this.picture, this.messageIds);
  
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

List<Event> readEventsFromFile(String filename) {
  List<Event> events = [];
  final File  file   = File(filename);

  // sync read
  try {
    List<String> lines = file.readAsLinesSync();
    for( int i = 0; i < lines.length; i++ ) {
          Event e = Event.fromJson(lines[i], "");
          events.add(e);
    }
  } on Exception catch(err) {
    print("Cannot open file $gEventsFilename");
  }

  return events;
}

// From the list of events provided, lookup the lastst contact information for the given user/pubkey
Event? getContactEvent(List<Event> events, String pubkey) {

    // get the latest kind 3 event for the user, which lists his 'follows' list
    int latestContactsTime = 0, latestContactIndex = -1;
    for( int i = 0; i < events.length; i++) {
      var e = events[i];
      if( e.eventData.pubkey == pubkey && e.eventData.kind == 3 && latestContactsTime < e.eventData.createdAt) {
        latestContactIndex = i;
        latestContactsTime = e.eventData.createdAt;
      }
    }

    // if contact list was found, get user's feed, and keep the contact list for later use 
    if (latestContactIndex != -1) {
      return events[latestContactIndex];
    }

    return null;
}

// for the user userPubkey, returns the relay of its contact contactPubkey
String getRelayOfUser(String userPubkey, String contactPubkey) {

  if(gDebug > 0) print("In getRelayOfUser: Searching relay for contact $contactPubkey" );

  String relay = "";
  if( userPubkey == "" || contactPubkey == "") {
    return "";
  }

  if( gContactLists.containsKey(userPubkey)) {
    List<Contact>? contacts = gContactLists[userPubkey];
    if( contacts != null) {
      for( int i = 0; i < contacts.length; i++) {
        //if( gDebug > 0) print(  contacts[i].toString()  );
        if( contacts[i].id == contactPubkey) {
          relay = contacts[i].relay;
          //if(gDebug > 0) print("In getRelayOfUser: found relay $relay for contact $contactPubkey" );
          return relay;
        }
      }
    }
  }
  // if not found return empty string
  return relay;
}

// returns full public key(s) for the given username( which can be first few letters of pubkey, or the user name)
Set<String> getPublicKeyFromName(String userName) {
  Set<String> pubkeys = {};

  gKindONames.forEach((key, value) {
    // check both the user name, and the pubkey to search for the user
    if( userName == value) {
      pubkeys.add(key);
    }

    if( key.substring(0, userName.length) == userName) {
      pubkeys.add(key);
    }
  });

  return pubkeys;
}
