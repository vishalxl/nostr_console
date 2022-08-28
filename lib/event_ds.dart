import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:translator/translator.dart';
import 'package:crypto/crypto.dart';
import 'package:nostr_console/settings.dart';

int gDebug = 0;

// global contact list of each user, including of the logged in user.
// maps from pubkey of a user, to the latest contact list of that user, which is the latest kind 3 message
// is updated as kind 3 events are received 
Map< String, List<Contact>> gContactLists = {};

final translator = GoogleTranslator();
const int gNumTranslateDays = 1;// translate for this number of days
bool gTranslate = false; // translate flag

void printUnderlined(String x) =>  { print("$x\n${getNumDashes(x.length)}")}; 

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

bool isWhitespace(String s) {
  if( s.length != 1) {
    return false;
  }
  return s[0] == ' ' || s[0] == '\n' || s[0] == '\r' || s[0] == '\t';
}


extension StringX on String {
  isEnglish( ) {
    // since smaller words can be smileys they should not be translated
    if( length < 6) 
      return true;
    
    if( !isLatinAlphabet())
      return false;

    if (isFrench())
      return false;

    return true;
  }

  bool isFrench() {

    // https://www.thoughtco.com/most-common-french-words-1372759
    List<String> frenchWords = ["oui", "je", "le", "un", "de", "et", "merci", "une", "ce", "pas"];
    for( int i = 0; i < frenchWords.length; i++) {
      if( this.toLowerCase().contains(" ${frenchWords[i]} ")) {
        if( gDebug > 0) print("isFrench: Found ${this.toString()} is french"); 
        return true;
      }
    }
    return false;
  }


  isLatinAlphabet({caseSensitive = false}) {
    int countLatinletters = 0;
    for (int i = 0; i < length; i++) {
      final target = caseSensitive ? this[i] : this[i].toLowerCase();
      if ( (target.codeUnitAt(0) > 96 && target.codeUnitAt(0) < 123)  || ( isNumeric(target) ) || isWhitespace(target)) {
        countLatinletters++; 
      }
    }
    
    if( countLatinletters < ( 40.0/100 ) * length ) {
      if( gDebug > 0) print("in isLatinAlphabet: latin letters: $countLatinletters and total = $length ");
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
        if( tag.length < 2) {
          if( gDebug > 0) print("In event fromjson: invalid p tag of size 1");
          continue;
        }

        String server = defaultServerUrl;
        if( tag.length >=3 ) {
          server = tag[2].toString();
          if( server == 'wss://nostr.rocks' || server == "wss://nostr.bitcoiner.social") {
            server = defaultServerUrl;
          }
        }

        if( tag[0] == "p" && tag[1].length == 64) {
          Contact c = Contact(tag[1] as String, server);
          contactList.add(c); 
        }
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

    if( json['id'] == gCheckEventId) {
      if(gDebug > 0) print("In Event fromJson: got message: $gCheckEventId");
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
    for(int i = 0; i < placeHolders.length && i < tags.length; i++) {
      int     index = -1;
      Pattern p     = placeHolders[i];
      if( (index = content.indexOf(p)) != -1 ) {
        if( tags[i].length >= 2) {
          String author = getAuthorName(tags[i][1]);
          content = "${content.substring(0, index)} @$author${content.substring(index + 4)}";
        }
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

      if( gTranslate && !evaluatedContent.isEnglish()) {
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
    if( id == gCheckEventId) {
      if(gDebug > 0) { 
        print("In Event printEventData: got message: $gCheckEventId");
        isNotification = true;
      }
    }

    int n = 4;
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
      printInColor(contentShifted, gNotificationColor);
      isNotification = false;
    } else {
      printInColor(contentShifted, gCommentColor);
    }
  }

  String getAsLine({int len = 20}) {
    if( len == 0 || len > content.length) {
      len = content.length;
    }

    return '"${content.substring(0, len)}..." - ${getAuthorName(pubkey)}';
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
          reactorNames += gNotificationColor + getAuthorName(reactorId) + colorEndMarker;
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

  @override
  bool operator ==( other) {
     return (other is Event) && eventData.id == other.eventData.id;
  }

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

void addToHistogram(Map<String, int> histogram, List<String> pTags) {
  Set tempPtags = {};
  pTags.retainWhere((x) =>  tempPtags.add(x));

  for(int i = 0; i < pTags.length; i++ ) {
    String pTag = pTags[i];
    if( histogram.containsKey(pTag)) {
      int? val = histogram[pTag];
      if( val != null) {
        histogram[pTag] = ++val;
      } else {
      }
    } else {
      histogram[pTag] = 1;
    }
  }
  //return histogram;
}

class HistogramEntry {
  String str;
  int    count;
  HistogramEntry(this.str, this.count);
  static int histogramSorter(HistogramEntry a, HistogramEntry b) {
    if( a.count < b.count ) {
      return 1;
    } if( a.count == b.count ) {
      return 0;
    } else {
      return -1;
    }
  }
}

// return the numMostFrequent number of most frequent p tags ( user pubkeys) in the given events
List<String> getpTags(Set<Event> events, int numMostFrequent) {
  List<HistogramEntry> listHistogram = [];
  Map<String, int>   histogramMap = {};
  for(var event in events) {
    addToHistogram(histogramMap, event.eventData.pTags);
  }

  histogramMap.forEach((key, value) {listHistogram.add(HistogramEntry(key, value));/* print("added to list of histogramEntry $key $value"); */});
  listHistogram.sort(HistogramEntry.histogramSorter);
  List<String> ptags = [];
  for( int i = 0; i < listHistogram.length && i < numMostFrequent; i++ ) {
    //print ( "${listHistogram[i].str} ${listHistogram[i].count} ");
    ptags.add(listHistogram[i].str);
  }

  return ptags;
}

Set<Event> readEventsFromFile(String filename) {
  Set<Event> events = {};
  final File  file   = File(filename);

  // sync read
  try {
    List<String> lines = file.readAsLinesSync();
    for( int i = 0; i < lines.length; i++ ) {
          Event e = Event.fromJson(lines[i], "");
          events.add(e);
    }
  } on Exception catch(err) {
    print("cannot open file $gEventsFilename");
  }

  return events;
}

// From the list of events provided, lookup the lastst contact information for the given user/pubkey
Event? getContactEvent(Set<Event> events, String pubkey) {

    // get the latest kind 3 event for the user, which lists his 'follows' list
    Event? latestContactEvent = null;
    int latestContactsTime = 0;
    for( var e in events) {
      if( e.eventData.pubkey == pubkey && e.eventData.kind == 3 && latestContactsTime < e.eventData.createdAt) {
        latestContactsTime = e.eventData.createdAt;
        latestContactEvent = e;
      }
    }

    return latestContactEvent;
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

// If given event is kind 0 event, then populates gKindONames with that info
void processKind0Event(Event e) {
  if( e.eventData.kind != 0) {
    return;
  }

  String content = e.eventData.content;
  if( content.isEmpty) {
    return;
  }

  String? name = "";
  String? about = "";
  String? picture = "";

  try {
    dynamic json = jsonDecode(content);
    name = json["name"];
    about = json["about"];    
    picture = json["picture"];    
  } catch(ex) {
    if( gDebug != 0) print("Warning: In processKind0Event: caught exception for content: ${e.eventData.content}");
    return;
  }


  if(name != Null) {
    if( !gKindONames.containsKey(e.eventData.pubkey)) {    
      gKindONames[e.eventData.pubkey] = UserNameInfo(e.eventData.createdAt, name??"", about??"", picture??"");
      //print("Created meta data for name: $name about: $about picture: $picture");
    } else {
      int oldTime = gKindONames[e.eventData.pubkey]?.createdAt??0;
      if( oldTime < e.eventData.createdAt) {
        String oldName = gKindONames[e.eventData.pubkey]?.name??"";
         gKindONames[e.eventData.pubkey] = UserNameInfo(e.eventData.createdAt, name??"", about??"", picture??"");
         //print("Updated meta data to name: $name  from $oldName");
      }
    }
  }
}

// returns name by looking up global list gKindONames, which is populated by kind 0 events
String getAuthorName(String pubkey) {
  String max3(String v) => v.length > 3? v.substring(0,3) : v.substring(0, v.length);
  String name = gKindONames[pubkey]?.name??max3(pubkey);
  return name;
}

// returns full public key(s) for the given username( which can be first few letters of pubkey, or the user name)
Set<String> getPublicKeyFromName(String userName) {
  Set<String> pubkeys = {};

  gKindONames.forEach((key, value) {
    // check both the user name, and the pubkey to search for the user
    if( userName == value.name) {
      pubkeys.add(key);
    }

    if( userName.length <= key.length) {
      if( key.substring(0, userName.length) == userName) {
        pubkeys.add(key);
      }
    }
  });

  return pubkeys;
}

// returns the seconds since eponch N days ago
int getSecondsDaysAgo( int N) {
  return  DateTime.now().subtract(Duration(days: N)).millisecondsSinceEpoch ~/ 1000;
}


