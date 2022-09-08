import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:translator/translator.dart';
import 'package:crypto/crypto.dart';
import 'package:nostr_console/settings.dart';
import "dart:typed_data";
import 'dart:convert' as convert;
import "package:pointycastle/export.dart";
import 'package:kepler/kepler.dart';

int gDebug = 0;



// translate 
GoogleTranslator? translator; // initialized in main when argument given
 
const int gNumTranslateDays = 2;// translate for this number of days
bool gTranslate = false; // translate flag

// Structure to store kind 0 event meta data, and kind 3 meta data for each user. Will have info from latest
// kind 0 event and/or kind 3 event, both with their own time stamps.
class UserNameInfo {
  int? createdAt;
  String? name, about, picture;
  int? createdAtKind3;
  Event ?latestContactEvent;
  UserNameInfo(this.createdAt, this.name, this.about, this.picture, this.latestContactEvent, [this.createdAtKind3 = null]);
}

/* 
 * global user names from kind 0 events, mapped from public key to a 3 element array of [name, about, picture]
 *  JSON object {name: <username>, about: <string>, picture: <url, string>}
 *  only has info from latest kind 0 event
 */
Map<String, UserNameInfo> gKindONames = {}; 

// global reactions entry. Map of form <if of event reacted to, List of Reactors>
// reach Reactor is a list of 2-elements ( first is public id of reactor event, second is comment)
Map< String, List<List<String>> > gReactions = {};

// global contact list of each user, including of the logged in user.
// maps from pubkey of a user, to the latest contact list of that user, which is the latest kind 3 message
// is updated as kind 3 events are received 
Map< String, List<Contact>> gContactLists = {};

class EventData {
  String             id;
  String             pubkey;
  int                createdAt;
  int                kind;
  String             content;
  List<String>       eTags;// e tags
  List<String>       pTags;// list of p tags for kind:1
  List<List<String>> tags;
  bool               isNotification; // whether its to be highlighted using highlight color
  String             evaluatedContent; // content which has mentions expanded, and which has been translated
  Set<String>        newLikes;    // user for notifications, are colored as notifications and then reset  

  List<Contact> contactList = []; // used for kind:3 events, which is contact list event

  bool               isHidden; // hidden by sending a reaction kind 7 event to this event, by the logged in user
  bool               isDeleted; // deleted by kind 5 event
  
  String getParent() {
    if( eTags.isNotEmpty) {
      return eTags[eTags.length - 1];
    }
    return "";
  }

  EventData(this.id, this.pubkey, this.createdAt, this.kind, this.content, this.eTags, this.pTags,
            this.contactList, this.tags, this.newLikes, {this.isNotification = false, this.evaluatedContent = "", this.isHidden = false, this.isDeleted = false});
   
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
      int eKind = json['kind'];
      if ( eKind == 1 || eKind == 7 || eKind == 42  || eKind == 5 || eKind == 4) {
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

    if( gDebug > 0 && json['id'] == gCheckEventId) {
      print("\n----------------------------------------Creating EventData with content: ${json['content']}");
      print("In Event fromJson: got message: $gCheckEventId");
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

  // is called only once for each event received ( or read from file)
  void translateAndExpandMentions() {
    if (content == "" ||  evaluatedContent != "") {
      return;
    }

    switch(kind) {
    case 1:
    case 42:
      evaluatedContent = expandMentions(content);
      if( translator != null && gTranslate && !evaluatedContent.isEnglish()) {
        if( gDebug > 0) print("found that this comment is non-English: $evaluatedContent");

        // only translate for latest events
        if( DateTime.fromMillisecondsSinceEpoch(createdAt *1000).compareTo( DateTime.now().subtract(Duration(days:gNumTranslateDays)) ) > 0 ) {
          if( gDebug > 0) print("Sending google request: translating $content");
          if( translator != null) {
            try {
            translator?.translate(content, to: 'en')
                      .then( (result) => { evaluatedContent =   "$evaluatedContent\n\nTranslation: ${result.toString()}" , if( gDebug > 0)  print("Google translate returned successfully for one call.")} 
                        );
            } on Exception catch(err) {
              if( gDebug >= 0) print("Info: Error in trying to use google translate: $err");
            }
          }
        }
      }
    break;

    case 4: 

      if( userPrivateKey == ""){ // cant process if private key not given
        break;
      }
      //if( pubkey == userPublicKey )  break; // crashes right now otherwise 
      if(!isValidDirectMessage(this)) {
        break;
      }
      String? decrypted = decryptContent();
      if( decrypted != null) {
        evaluatedContent = decrypted;
      }
      break;
    } // end switch
  } // end translateAndExpandMentions

  String? decryptContent() {
    int ivIndex = content.indexOf("?iv=");
    var iv = content.substring( ivIndex + 4, content.length);
    var enc_str = content.substring(0, ivIndex);

    String userKey = userPrivateKey ;
    String otherUserPubKey = "02" + pubkey;
    if( pubkey == userPublicKey) { // if user themselve is the sender change public key used to decrypt
      userKey =  userPrivateKey;
      int numPtags = 0;
      tags.forEach((tag) {
        if(tag[0] == "p" ) {
          otherUserPubKey = "02" + tag[1];
          numPtags++;
        }
      }); 
      // if there are more than one p tags, we don't know who its for
      if( numPtags != 1) {
        if( gDebug >= 0) print(" in translateAndExpand: got event $id with number of p tags != one : $numPtags . not decrypting");
          return null;
      }
    } 
    //print("going to decrypt eventid : $id to be decrypted content: $enc_str");
    //print("original message: $content");
    var decrypted = myPrivateDecrypt( userKey, otherUserPubKey, enc_str, iv); // use bob's privatekey and alic's publickey means bob can read message from alic
    //print("decrypted: $evaluatedContent\n---------------");
    return decrypted;
  }

  // only applicable for kind 42 event
  String getChannelIdForMessage() {
    if( kind != 42) {
      return "";
    }
    return getParent();
  }

  // prints event data in the format that allows it to be shown in tree form by the Tree class
  void printEventData(int depth) {
    if( !(kind == 1 || kind == 4 || kind == 42)) {
      return; // only print kind 1 and 42 and 4
    }

    int n = 4;
    String maxN(String v)       => v.length > n? v.substring(0,n) : v.substring(0, v.length);
    void   printInColor(String s, String commentColor) => stdout.supportsAnsiEscapes ?stdout.write("$commentColor$s$gColorEndMarker"):stdout.write(s);
    String getStrInColor(String s, String commentColor) => stdout.supportsAnsiEscapes ?"$commentColor$s$gColorEndMarker":s;

    String name = getAuthorName(pubkey);    
    String strDate = getPrintableDate(createdAt);
    String tempEvaluatedContent = evaluatedContent;
    String tempContent = content;

    if( isHidden) {
      name = "<hidden>";
      strDate = "<hidden>";
      tempEvaluatedContent = tempContent = "<You have hidden this post>";
    }

    // delete supercedes hidden
    if( isDeleted) {
      name = "<deleted>";
      strDate = "<deleted>";
      tempEvaluatedContent = tempContent = content; // content would be changed so show that 
    }

    if( createdAt == 0) {
      print("debug: createdAt == 0 for event $id $content");
    }
   
    String contentShifted = rightShiftContent(tempEvaluatedContent==""?tempContent: tempEvaluatedContent, gSpacesPerDepth * depth + 10);
    
    String strToPrint = "";

    strToPrint += getDepthSpaces(depth);
    strToPrint += ("+-------+\n");
    strToPrint += getDepthSpaces(depth);
    strToPrint += "|Author : $name  id: ${maxN(id)}  Time: $strDate\n";
    strToPrint += getReactionStr(depth);    // only prints if there are any likes/reactions
    strToPrint += getDepthSpaces(depth);
    strToPrint += "|Message: ";
 
    String commentColor = "";
    if( isNotification) {
      commentColor = gNotificationColor;
      isNotification = false;
    } else {
      commentColor = gCommentColor;
    }
    strToPrint += getStrInColor(contentShifted , commentColor);
    stdout.write(strToPrint);
  }

  String getAsLine({int len = 20}) {
    String contentToPrint = evaluatedContent.isEmpty? content: evaluatedContent;
    //print("$contentToPrint|");
    //print("len = ${contentToPrint.length}");
    if( len == 0 || len > contentToPrint.length) {
      len = contentToPrint.length;
    }
    
    contentToPrint = contentToPrint.padLeft(len);
    contentToPrint = contentToPrint.replaceAll("\n", " ");
    contentToPrint = contentToPrint.replaceAll("\r", " ");
    String strToPrint = '${contentToPrint.substring(0, len)}... - ${getAuthorName(pubkey)}';

    int strWidth = 40;
    String paddedStrToPrint = strToPrint.padLeft(strWidth);
    //print("\n$paddedStrToPrint");
    paddedStrToPrint = paddedStrToPrint.substring(0, strWidth);

    if( isNotification) {
      paddedStrToPrint = "$gNotificationColor$paddedStrToPrint$gColorEndMarker";
      isNotification = false;
    }
    return paddedStrToPrint;
  }

  String getStrForChannel(int depth) {
    String strToPrint = "";
    String name = getAuthorName(pubkey);    
    String strDate = getPrintableDate(createdAt);
    String tempEvaluatedContent = evaluatedContent;
    String tempContent = evaluatedContent.isEmpty? content: evaluatedContent;
    
    if( isHidden) {
      name = strDate = "<hidden>";
      tempEvaluatedContent = tempContent = "<You have hidden this post>";
    }

    // delete supercedes hidden
    if( isDeleted) {
      name = strDate = "<deleted>";
      tempEvaluatedContent = tempContent = content; // content would be changed so show that 
    }

    const int nameWidthDepth = 2; // how wide name will be in depth spaces
    const int timeWidthDepth = 2;
    int nameWidth = gSpacesPerDepth * nameWidthDepth;
    String nameToPrint = name.padLeft(nameWidth).substring(0, nameWidth);
    String dateToPrint = strDate.padLeft(gSpacesPerDepth * timeWidthDepth).substring(0, gSpacesPerDepth * timeWidthDepth);

    strToPrint = "${getDepthSpaces(depth)}  $dateToPrint    $nameToPrint: ";
    // depth above + ( depth numberof spaces = 1) + (depth of time = 2) + (depth of name = 3)
    int contentDepth = depth + 1 + timeWidthDepth + nameWidthDepth;
    String contentShifted = rightShiftContent(tempEvaluatedContent==""?tempContent: tempEvaluatedContent, gSpacesPerDepth * contentDepth);
    strToPrint += contentShifted;
    if( isNotification) {
      strToPrint = "$gNotificationColor$strToPrint$gColorEndMarker";
      isNotification = false;
    }
    return strToPrint;
  }


  // looks up global map of reactions, if this event has any reactions, and then prints the reactions
  // in appropriate color( in case one is a notification, which is stored in member variable)
  String getReactionStr(int depth) {
    String reactorNames = "";

    if( isHidden  ||  isDeleted) {
      return "";
    }

    if( gReactions.containsKey(id)) {
      reactorNames = getDepthSpaces(depth) + "|Likes  : ";
      int numReactions = gReactions[id]?.length??0;
      List<List<String>> reactors = gReactions[id]??[];
      bool firstEntry = true;
      for( int i = 0; i <numReactions; i++) {
        
        String comma = (firstEntry)?"":", ";

        String reactorId = reactors[i][0];
        if( newLikes.contains(reactorId) && reactors[i][1] == "+") {
          // this is a notifications, print it and then later empty newLikes
          reactorNames += comma + gNotificationColor + getAuthorName(reactorId) + gColorEndMarker;
          firstEntry = false;
        } else {
          // this is normal printing of the reaction. only print for + for now
          if( reactors[i][1] == "+")
            reactorNames += comma + getAuthorName(reactorId);
            firstEntry = false;
        }
      } // end for
      newLikes.clear();
      reactorNames += "\n";
    }
    
    return reactorNames;
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
  bool readFromFile;

  Event(this.event, this.id, this.eventData, this.seenOnRelays, this.originalJson, [this.readFromFile = false]);

  @override
  bool operator ==( other) {
     return (other is Event) && eventData.id == other.eventData.id;
  }

  factory Event.fromJson(String d, String relay, [bool fromFile = false]) {
    try {
      dynamic json = jsonDecode(d);
      if( json.length < 3) {
        String e = "";
        e = json.length > 1? json[0]: "";
        if( gDebug> 0) {
          print("Could not create event. returning dummy event. json.length = ${json.length} string d= $d $e");
        }
        return Event(e,"",EventData("non","", 0, 0, "", [], [], [], [[]], {}), [relay], "[json]", fromFile);
      }
      EventData newEventData = EventData.fromJson(json[2]);
      if( !fromFile) 
        newEventData.isNotification = true;
      return Event(json[0] as String, json[1] as String, newEventData, [relay], d, fromFile );
    } on Exception catch(e) {
      if( gDebug> 0) {
        print("Could not create event. returning dummy event. $e");
      }
      return Event("","",EventData("non","", 0, 0, "", [], [], [], [[]], {}), [relay], "[json]", fromFile);
    }
  }

  void printEvent(int depth) {
    eventData.printEventData(depth);
    //print("\n$seenOnRelays");
    //stdout.write("\n$originalJson --------------------------------\n\n");
  }

  @override 
  String toString() {
    return '$eventData     Seen on: ${seenOnRelays[0]}\n';
  }
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

// From the list of events provided, lookup the lastst contact information for the given user/pubkey
Event? getContactEvent(String pubkey) {

    // get the latest kind 3 event for the user, which lists his 'follows' list
    if( gKindONames.containsKey(pubkey)) {
      Event? e = (gKindONames[pubkey]?.latestContactEvent)??null;
      return e;
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

// If given event is kind 0 event, then populates gKindONames with that info
// returns true if entry was created or modified, false otherwise
bool processKind0Event(Event e) {
  if( e.eventData.kind != 0) {
    return false;
  }

  String content = e.eventData.content;
  if( content.isEmpty) {
    return false;
  }

  String name = "";
  String about = "";
  String picture = "";

  try {
    dynamic json = jsonDecode(content);
    name = json["name"];
    about = json["about"];    
    picture = json["picture"];    
  } catch(ex) {
    //if( gDebug != 0) print("Warning: In processKind0Event: caught exception for content: ${e.eventData.content}");
    if( name.isEmpty) {
      //return false;
    }
  }

  bool newEntry = false, entryModified = false;
  if( !gKindONames.containsKey(e.eventData.pubkey)) {    
    gKindONames[e.eventData.pubkey] = UserNameInfo(e.eventData.createdAt, name, about, picture, null);
    newEntry = true;;
  } else {
    int oldTime = gKindONames[e.eventData.pubkey]?.createdAt??0;
    if( oldTime < e.eventData.createdAt) {
      Event? oldContactEvent = gKindONames[e.eventData.pubkey]?.latestContactEvent;
      gKindONames[e.eventData.pubkey] = UserNameInfo(e.eventData.createdAt, name, about, picture, oldContactEvent);
      entryModified = true;;
    }
  }

  if(gDebug > 0) { 
    print("At end of processKind0Events: for name = $name ${newEntry? "added entry": ( entryModified?"modified entry": "No change done")} ");
  }
  return newEntry || entryModified;
}

// If given event is kind 3 event, then populates gKindONames with contact info
// returns true if entry was created or modified, false otherwise
bool processKind3Event(Event newContactEvent) {
  if( newContactEvent.eventData.kind != 3) {
    return false;
  }

  bool newEntry = false, entryModified = false;
  if( !gKindONames.containsKey(newContactEvent.eventData.pubkey)) {
    gKindONames[newContactEvent.eventData.pubkey] = UserNameInfo(null, null, null, null, newContactEvent, newContactEvent.eventData.createdAt);
    newEntry = true;;
  } else {
    // if entry already exists, then check its old time and update only if we have a newer entry now
    int oldTime = gKindONames[newContactEvent.eventData.pubkey]?.createdAtKind3??0;
    if( oldTime < newContactEvent.eventData.createdAt) {
      int? createdAt = gKindONames[newContactEvent.eventData.pubkey]?.createdAt??null;
      String? name = gKindONames[newContactEvent.eventData.pubkey]?.name, about = gKindONames[newContactEvent.eventData.pubkey]?.about, picture = gKindONames[newContactEvent.eventData.pubkey]?.picture;
      
      gKindONames[newContactEvent.eventData.pubkey] = UserNameInfo(createdAt, name, about, picture, newContactEvent, newContactEvent.eventData.createdAt );
      entryModified = true;;
    }
  }

  if(gDebug > 0) { 
      print("At end of processKind3Events:  ${newEntry? "added entry": ( entryModified?"modified entry": "No change done")} ");
  }
  return newEntry || entryModified;
}

// returns name by looking up global list gKindONames, which is populated by kind 0 events
String getAuthorName(String pubkey, [int len = 3]) {
  String max3(String v) => v.length > len? v.substring(0,len) : v.substring(0, v.length);
  String name = gKindONames[pubkey]?.name??max3(pubkey);
  return name;
}

// returns full public key(s) for the given username( which can be first few letters of pubkey, or the user name)
Set<String> getPublicKeyFromName(String userName) {
  Set<String> pubkeys = {};

  //if(gDebug > 0) print("In getPublicKeyFromName: doing lookup for $userName len of gKindONames= ${gKindONames.length}");

  gKindONames.forEach((pk, userInfo) {
    // check both the user name, and the pubkey to search for the user
    //print(userInfo.name);
    if( userName == userInfo.name) {
      pubkeys.add(pk);
    }

    if( userName.length <= pk.length) {
      //print("$pk $userName" );
      if( pk.substring(0, userName.length) == userName) {
        pubkeys.add(pk);
      }
    }
  });

  return pubkeys;
}

// returns the seconds since eponch N days ago
int getSecondsDaysAgo( int N) {
  return  DateTime.now().subtract(Duration(days: N)).millisecondsSinceEpoch ~/ 1000;
}

void printUnderlined(String x) =>  { print("$x\n${getNumDashes(x.length)}")}; 

void printDepth(int d) {
  for( int i = 0; i < gSpacesPerDepth * d + gNumLeftMarginSpaces; i++) {
    stdout.write(" ");
  }
}

void printCenteredHeadline(displayName) {
  int numDashes = 10; // num of dashes on each side
  int startText = gNumLeftMarginSpaces + ( gTextWidth - (displayName.length + 2 * numDashes)) ~/ 2; 
  if( startText < 0) 
    startText = 0;

  String str = getNumSpaces(startText) + getNumDashes(numDashes) + displayName + getNumDashes(numDashes);
  print(str);
   
}

String getDepthSpaces(int d) {
  String str = "";
  for( int i = 0; i < gSpacesPerDepth * d + gNumLeftMarginSpaces; i++) {
    str += " ";
  }
  return str;
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
  int    numCharsInCurLine = 0;
  String spacesString = getNumSpaces(numSpaces + gNumLeftMarginSpaces);

  for(int i = 0; i < s.length; i++) {
    if( s[i] == '\n') {
      newString += "\n";
      newString += spacesString;
      numCharsInCurLine = 0;
    } else {
      if( numCharsInCurLine >= (gTextWidth - numSpaces)) {
        if( i > 1 &&  !isWordSeparater(s[i])) {
          // go back in output string and readjust it if needed
          const int lookForSpace = 6;
          bool foundSpace = false;
          for(int j = 0; j < min(newString.length, lookForSpace); j++) {
            if( newString[newString.length-1-j] == " ") {
              foundSpace = true;
              String charsInNextLine = "";
              charsInNextLine = newString.substring(newString.length-j, newString.length);
              String temp = newString.substring(0, newString.length-j) + "\n" + spacesString + charsInNextLine;
              newString = temp;
              numCharsInCurLine = charsInNextLine.length;
              break;
            }
          }
          if(!foundSpace) {
            newString += "\n";
            newString += spacesString;
            numCharsInCurLine = 0;
          }
        } else {
          newString += "\n";
          newString += spacesString;
          numCharsInCurLine = 0;
        }
      } 
      newString += s[i];
    }
    numCharsInCurLine++;
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

bool isWordSeparater(String s) {
  if( s.length != 1) {
    return false;
  }
  return s[0] == ' ' || s[0] == '\n' || s[0] == '\r' || s[0] == '\t' 
      || s[0] == ',' || s[0] == '.' || s[0] == '-' || s[0] == '('|| s[0] == ')';
}


bool isWhitespace(String s) {
  if( s.length != 1) {
    return false;
  }
  return s[0] == ' ' || s[0] == '\n' || s[0] == '\r' || s[0] == '\t';
}

extension StringX on String {


  isChannelPageNumber(int max) {
  
  int? n = int.tryParse(this);
  if( n != null) {
    if( n < max)
      return true;
  }
  return false;
  }

  isEnglish( ) {
    // since smaller words can be smileys they should not be translated
    if( length < 10) 
      return true;
    
    if( !isLatinAlphabet())
      return false;

    if (isFrench())
      return false;

    return true;
  }

  isPortugese() {
    false; // https://1000mostcommonwords.com/1000-most-common-portuguese-words/
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
  var bufInBytes = utf8.encode(buf);
  var value = sha256.convert(bufInBytes);
  return value.toString();
}

// get printable date from seconds since epoch
String getPrintableDate(int createdAt) {
  final df1 = DateFormat('hh:mm a');
  final df2 = DateFormat(DateFormat.ABBR_MONTH_DAY);
  String strDate = df1.format(DateTime.fromMillisecondsSinceEpoch(createdAt*1000));
  strDate += " ${df2.format(DateTime.fromMillisecondsSinceEpoch(createdAt*1000))}";
  return strDate;
}

/*
 * Returns true if this is a valid direct message to just this user
 */
bool isValidDirectMessage(EventData directMessageData) {
  bool validUserMessage = false;

  List<String> allPtags = [];
  directMessageData.tags.forEach((tag) {
    if( tag.length < 2 )
      return;
    if( tag[0] == "p" && tag[1].length == 64) { // basic length sanity test
      allPtags.add(tag[1]);
    }
  });

  if( directMessageData.pubkey == userPublicKey && allPtags.length == 1) {
    validUserMessage = true; // case where this user is sender
  } else {
    if ( directMessageData.pubkey != userPublicKey) {
      if( allPtags.length == 1 && allPtags[0] == userPublicKey) {
        validUserMessage = true; // case where this user is recipeint 
      }
    }
  }
  return validUserMessage;
}

   
// pointy castle source https://github.com/PointyCastle/pointycastle/blob/master/tutorials/aes-cbc.md
// https://github.com/bcgit/pc-dart/blob/master/tutorials/aes-cbc.md
// 3 https://github.com/Dhuliang/flutter-bsv/blob/42a2d92ec6bb9ee3231878ffe684e1b7940c7d49/lib/src/aescbc.dart

/// Decrypt data using self private key
String myPrivateDecrypt( String privateString, 
                         String publicString, 
                         String b64encoded,
                        [String b64IV = ""]) {

  Uint8List encdData = convert.base64.decode(b64encoded);
  final rawData = myPrivateDecryptRaw(privateString, publicString, encdData, b64IV);
  return convert.Utf8Decoder().convert(rawData.toList());
}


Map<String, List<List<int>>> gMapByteSecret = {};

Uint8List myPrivateDecryptRaw( String privateString, 
                               String publicString, 
                               Uint8List cipherText,
                               [String b64IV = ""]) {
try {

  List<List<int>> byteSecret = [];
  if( gMapByteSecret.containsKey(publicString)) {
      byteSecret = gMapByteSecret[publicString]??[];
  }

  if( byteSecret.isEmpty) {
    byteSecret = Kepler.byteSecret(privateString, publicString);;
    gMapByteSecret[publicString] = byteSecret;
  }

  final secretIV = byteSecret;
  
  final key = Uint8List.fromList(secretIV[0]);

  final iv = b64IV.length > 6
      ? convert.base64.decode(b64IV)
      : Uint8List.fromList(secretIV[1]);


  CipherParameters params = new PaddedBlockCipherParameters(
      new ParametersWithIV(new KeyParameter(key), iv), null);

  PaddedBlockCipherImpl cipherImpl = new PaddedBlockCipherImpl(
      new PKCS7Padding(), new CBCBlockCipher(new AESEngine()));


  cipherImpl.init(false,
                  params as PaddedBlockCipherParameters<CipherParameters?,
                                                        CipherParameters?>);

  final Uint8List  finalPlainText = Uint8List(cipherText.length); // allocate space

  var offset = 0;
  while (offset < cipherText.length - 16) {
    offset += cipherImpl.processBlock(cipherText, offset, finalPlainText, offset);
  }

  //remove padding
  offset += cipherImpl.doFinal(cipherText, offset, finalPlainText, offset);
  assert(offset == cipherText.length);
  return  finalPlainText.sublist(0, offset);
} catch(e) {
    //print("cannot open file $gEventsFilename");
    if( gDebug >= 0) print("Decryption error =  $e");
    return Uint8List(0);
}
}

/// Encrypt data using self private key in nostr format ( with trailing ?iv=)
String myEncrypt( String privateString, 
                         String publicString, 
                         String plainText) {
  //Uint8List encdData = convert.base64.decode(b64encoded);
  Uint8List uintInputText = convert.Utf8Encoder().convert(plainText);
  final encryptedString = myEncryptRaw(privateString, publicString, uintInputText);
  return encryptedString;
  //return convert.Utf8Decoder().convert(rawData.toList());
}

String myEncryptRaw( String privateString, 
                     String publicString, 
                     Uint8List uintInputText) {
  final secretIV = Kepler.byteSecret(privateString, publicString);
  final key = Uint8List.fromList(secretIV[0]);

  // generate iv  https://stackoverflow.com/questions/63630661/aes-engine-not-initialised-with-pointycastle-securerandom
  FortunaRandom fr = FortunaRandom();
  final _sGen = Random.secure();;
  fr.seed(KeyParameter(
      Uint8List.fromList(List.generate(32, (_) => _sGen.nextInt(255)))));
  final iv = fr.nextBytes(16); //Uint8List.fromList(secretIV[1]);
  //print("iv = $iv");
   
  CipherParameters params = new PaddedBlockCipherParameters(
      new ParametersWithIV(new KeyParameter(key), iv), null);

  PaddedBlockCipherImpl cipherImpl = new PaddedBlockCipherImpl(
      new PKCS7Padding(), new CBCBlockCipher(new AESEngine()));

  cipherImpl.init(true,  // means to encrypt
                  params as PaddedBlockCipherParameters<CipherParameters?,
                                                        CipherParameters?>);
  
  final Uint8List  outputEncodedText = Uint8List(uintInputText.length + 16); // allocate space

  var offset = 0;
  //print("    uintInputText len = ${uintInputText.length} ");
  while (offset < uintInputText.length - 16) {
    //print("       in while offset: $offset");
    offset += cipherImpl.processBlock(uintInputText, offset, outputEncodedText, offset);
  }

  //add padding 
  offset += cipherImpl.doFinal(uintInputText, offset, outputEncodedText, offset);
  assert(offset == uintInputText.length);
  final Uint8List finalEncodedText = outputEncodedText.sublist(0, offset);
  //print("    final offset after doFinal in encrypting: $offset finalEncodedText.lenth = ${finalEncodedText.length}");

  String stringIv = convert.base64.encode(iv);;
  String outputPlainText = convert.base64.encode(finalEncodedText);
  //print("    outputPlainText = $outputPlainText len = ${outputPlainText.length}");
  outputPlainText = outputPlainText + "?iv=" + stringIv;
  return  outputPlainText;
}


Set<Event> readEventsFromFile(String filename) {
  Set<Event> events = {};
  final File  file   = File(filename);

  // sync read
  try {
    List<String> lines = file.readAsLinesSync();
    for( int i = 0; i < lines.length; i++ ) {
        Event e = Event.fromJson(lines[i], "", true);
        events.add(e);
    }
  } on Exception catch(e) {
    //print("cannot open file $gEventsFilename");
    if( gDebug > 0) print("Could not open file. error =  $e");
  }

  if( gDebug > 0) print("In readEventsFromFile: returning ${events.length} total events");
  return events;
}

bool isValidPubkey(String pubkey) {
  if( pubkey.length == 64) {
    return true;
  }

  return false;
}