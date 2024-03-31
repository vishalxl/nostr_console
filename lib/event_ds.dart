import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:bip340/bip340.dart';
import 'package:intl/intl.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/user.dart';
import 'package:nostr_console/utils.dart';
import 'package:translator/translator.dart';
import 'package:crypto/crypto.dart';
import 'package:nostr_console/settings.dart';
import "dart:typed_data";
import 'dart:convert' as convert;
import "package:pointycastle/export.dart";
import 'package:kepler/kepler.dart';
import 'package:http/http.dart' as http;

String getStrInColor(String s, String commentColor) => stdout.supportsAnsiEscapes ?"$commentColor$s$gColorEndMarker":s;
void   printInColor(String s, String commentColor) => stdout.supportsAnsiEscapes ?stdout.write("$commentColor$s$gColorEndMarker"):stdout.write(s);
void   printWarning(String s) => stdout.supportsAnsiEscapes ?stdout.write("$gWarningColor$s$gColorEndMarker\n"):stdout.write("$s\n");

// translate 
GoogleTranslator? translator; // initialized in main when argument given
 
const int gNumTranslateDays = 1;// translate for this number of days
bool gTranslate = false; // translate flag
int numEventsTranslated = 0;

List<String> nip08PlaceHolders = ["#[0]", "#[1]", "#[2]", "#[3]", "#[4]", "#[5]", "#[6]", "#[7]", "#[8]", "#[9]", "#[10]", "#[11]", "#[12]"];


// Structure to store kind 0 event meta data, and kind 3 meta data for each user. Will have info from latest
// kind 0 event and/or kind 3 event, both with their own time stamps.
class UserNameInfo {
  int? createdAt;
  String? name, about, picture, lud06, lud16, display_name, website;
  int? createdAtKind3;
  Event ?latestContactEvent;
  bool nip05Verified;
  String? nip05Id;
  UserNameInfo(this.createdAt, this.name, this.about, this.picture, this.lud06, this.lud16, this.display_name, this.website, this.nip05Id , this.latestContactEvent,  [this.createdAtKind3, this.nip05Verified = false]);
}

/* 
 * global user names from kind 0 events, mapped from public key to a 3 element array of [name, about, picture]
 *  JSON object {name: <username>, about: <string>, picture: <url, string>}
 *  only has info from latest kind 0 event
 */
Map<String, UserNameInfo> gKindONames = {}; 

// global reactions entry. Map of form <id of event reacted to, List of Reactors>
// reach Reactor is a list of 2-elements ( first is pubkey of reactor event, second is comment)
// each eventID -> multiple [ pubkey, comment ]
Map< String, List<List<String>> > gReactions = {};

// for the given eventID returns the pubkeys of reactors
Set<String> getReactorPubkeys(String eventId) {
  Set<String> reactorIds = {};
  List<List<String>>? reactions = gReactions[eventId];

  if( reactions != null) {
    for (var reaction in reactions) { reactorIds.add(reaction[0]);}
  }

  return reactorIds;
}
// global contact list of each user, including of the logged in user.
// maps from pubkey of a user, to the latest contact list of that user, which is the latest kind 3 message
// is updated as kind 3 events are received 
Map< String, List<Contact>> gContactLists = {};

bool verifyEvent(dynamic json) {
    return true;

    gSpecificDebug = 0;
    if(gSpecificDebug > 0) print("----\nIn verify event:");
    String createdAt = json['created_at'].toString();

    String strTags = getStrTagsFromJson(json['tags']);

    //print("strTags = $strTags");

    String id = json['id'];
    String eventPubkey = json['pubkey'];
    String strKind = json['kind'].toString();
    String content = json['content'];
    content = unEscapeChars( content);
    String eventSig = json['sig'];

    
    if( false) {
      String calculatedId = getShaId(eventPubkey, createdAt.toString(), strKind, strTags, content);
      bool verified = true;//verify( eventPubkey, calculatedId, eventSig);

      if( !verified && !eventPubkey.startsWith("00")) {
        if(gSpecificDebug > 0) printWarning("\nwrong sig event\nevent sig     = $eventSig\nevent id      = $id\ncalculated id = $calculatedId " );
        if(gSpecificDebug > 0) print("Event: kind = $strKind\n");
        //getShaId(eventPubkey, createdAt.toString(), strKind, strTags, content);
        //print("$json");
        //throw Exception();
      } else {
        if(gSpecificDebug > 0) printInColor("\nverified correct sig for event id $id\n", gCommentColor);
      }
    }

    return true;
}

class EventData {
  String             id;
  String             pubkey;
  int                createdAt;
  int                kind;
  String             content;
  List<List<String>>       eTags;// e tags
  List<String>       pTags;// list of p tags 
  List<List<String>> tags;
  bool               isNotification; // whether its to be highlighted using highlight color
  String             evaluatedContent; // content which has mentions expanded, and which has been translated
  Set<String>        newLikes;    // used for notifications, are colored as notifications and then reset ; set of pubkeys that are new likers

  List<Contact> contactList = []; // used for kind:3 events, which is contact list event

  bool               isHidden; // hidden by sending a reaction kind 7 event to this event, by the logged in user
  bool               isDeleted; // deleted by kind 5 event


  EventData(this.id,          this.pubkey,   this.createdAt,  this.kind,  this.content,   
            this.eTags,   this.pTags,        this.contactList,this.tags,  this.newLikes,   
            {
              this.isNotification = false, this.evaluatedContent = "", this.isHidden = false, this.isDeleted = false
            });


  // returns the immediate kind 1 parent
  String getParent(Map<String, Tree> allEventsMap) {

    if( eTags.isNotEmpty) {

      int numRoot = 0, numReply = 0;

      // first go over all tags and find out at least one reply and root tag, and count their numbers
      String rootId = "", replyId = "";
      for( int i = 0; i < eTags.length; i++) {
        String eventId = eTags[i][0];
        if( eTags[i].length >= 3) {
          if( eTags[i][2].toLowerCase() == "root") {
            numRoot++;
            rootId = eventId;
          } else {
            if( eTags[i][2].toLowerCase() == "reply") {
              numReply++;
              replyId = eventId;
            }
          }
        }
      }
  
      // then depending on the numbers and values ( of root and replyto) return the parent
      if( replyId.isNotEmpty) {
        if( numReply == 1) {
          return replyId;
        } else {
          // if there are multiply reply's we can't tell which is which, so we return the one at top
          if( replyId.isNotEmpty) { 
            return replyId;  
          } else {
            // this is case when there is no reply id . should not actually happen given if conditions
            if( rootId.isNotEmpty) {
              return rootId;
            }
          }
        }
      } else {
        if( rootId.isNotEmpty) {
          //printWarning("returning root id. no reply id found.");
          return rootId;
        }
      }


      // but if reply/root tags don't work, then try to look for parent tag with the deprecated logic from NIP-10
      //if( gDebug > 0) log.info("using deprecated logic of nip10 for event id : $id");
      for( int i = tags.length - 1; i >= 0; i--) {
        if( tags[i][0] == "e") {
          String eventId = tags[i][1];
      
          // ignore this e tag if its mentioned in the body of the event
          String placeholder = nip08PlaceHolders.length > i? nip08PlaceHolders[i]: "INVALIDPLACEHOLDER_SHOULDNOTEXIST";
          if( content.contains(placeholder)) {
            continue;
          }

          if( allEventsMap[eventId]?.event.eventData.kind == 1) {
            String? parentId = allEventsMap[eventId]?.event.eventData.id;
            if( parentId != null) {
              return parentId;
            }
          } else {
            // if first e tag ( from end, which is the immediate parent) does not exist in the store, then return that eventID still. 
            // Child comment would get a dummy parent, and called could then fetch that event
            return eventId;
          }
        }
      }

    }
    return "";
  }

  List<String>? getTTags() {
    List<String>? tTags;

    for( int i = 0; i < tags.length; i++) {
      List<String> tag = tags[i];
      if( tag.length < 2) {
        continue;
      }
      if( tag[0] == 't') {
        tTags ??= [];

        tTags.add(tag[1]);
      }
    }

    return tTags;
  }

  // returns valueof location tag if present. returns null if that tag is not present. 
  String? getSpecificTag(String tagName) {

    for( int i = 0; i < tags.length; i++) {
      List<String> tag = tags[i];
      if( tag.length < 2) {
        continue;
      }
      if( tag[0] == tagName) {
        // return the first value
        return tag[1];
      }
    }

    return null;
  }

  factory EventData.fromJson(dynamic json) {
    
    List<Contact> contactList = [];

    List<List<String>> eTagsRead = [];
    List<String> pTagsRead = [];
    List<List<String>> tagsRead = [];

    var jsonTags = json['tags'];      
    var numTags = jsonTags.length;


    //print("\n----\nIn fromJson\n");
    String sig = json['sig'];
    if(sig.length == 128) {
      //print("found sig == 128 bytes");
      //if(json['id'] == "15dd45769dd0ccb9c4ca1c69fcd27011d53c4b95c8b7c786265bf7377bc7fdad") {
      //  printInColor("found 15dd45769dd0ccb9c4ca1c69fcd27011d53c4b95c8b7c786265bf7377bc7fdad sig ${json['sig']}", gCommentColor);
      //}

      try {
        verifyEvent(json);

      } on Exception {
        //printWarning("verify gave exception $e");
        throw Exception("in Event constructor: sig verify gave exception");
      }

    }

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
          if( server == 'wss://nostr.rocks' || server == "wss://offchain.pub") {
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
      if ( eKind == 1 || eKind == 7 || eKind == 42  || eKind == 5 || eKind == 4 || eKind == 140 || eKind == 141 || eKind == 142 || eKind == gSecretMessageKind) {
        for( int i = 0; i < numTags; i++) {
          var tag = jsonTags[i];

          if( tag.isEmpty) {
            continue;
          }
          if( tag[0] == "e") {
            List<String> listTag = [];
            for(int i = 1; i < tag.length; i ++) {
              listTag.add(tag[i]);
            }
            eTagsRead.add(listTag);
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

  String expandMentions(String content, Map<String, Tree> tempChildEventsMap) {
    if( tags.isEmpty) {
      return content;
    }

    // just check if there is any square bracket in comment, if not we return
    String squareBracketStart = "[", squareBracketEnd = "]";
    if( !content.contains(squareBracketStart) || !content.contains(squareBracketEnd) ) {
      return content;
    }

    String replaceMentions(Match mentionTagMatch) {
      String? mentionTag = mentionTagMatch.group(0);
      if( mentionTag != null) {
        String strInt = mentionTag.substring(2, mentionTag.length -1);
        int? n = int.tryParse(strInt);
        if( n != null) {
          if( n < tags.length) {
            String mentionedId = tags[n][1];

            if( gKindONames.containsKey(mentionedId)) {
              String author = getAuthorName(mentionedId);
              return "@$author";
            } else {
              EventData? eventData = tempChildEventsMap[mentionedId]?.event.eventData;
              if( eventData != null) {
                String quotedAuthor = getAuthorName(eventData.pubkey);
                String prefixId = mentionedId.substring(0, 3);
                String quote = "<Quoted event id '$prefixId' by $quotedAuthor: \"${eventData.evaluatedContent}\">";
                return quote;
              }
            }

            String tag = "";
            switch(tags[n][0]) {
            case "p":
              tag = "@";
              break;
            case "e":
              tag = "#";
              break;
            case "%": // something else for future
              tag = "%";
              break;
            default: 
              tag = "@";
            }


            return tag+mentionedId;

          }
        }

        return mentionTag;
      }
      if( gDebug > 0) printWarning("In replaceMentions returning nothing");
      return "";
    }

    // replace the mentions, if any are found
    String mentionStr = "(#[[0-9]+])";
    RegExp mentionRegExp = RegExp(mentionStr);
    content = content.replaceAllMapped(mentionRegExp, replaceMentions);
    return content;
  }

  // is called only once for each event received ( or read from file)
  void  translateAndExpandMentions(Map<String, Tree> tempChildEventsMap) {
    if( id == gCheckEventId) {
      //printInColor("in translateAndExpandMentions: decoding $gCheckEventId\n", redColor);
    }

    if (content == "" ||  evaluatedContent != "") {
      if( id == gCheckEventId) {
        //printInColor("in translateAndExpandMentions: returning \n", redColor);
      }
      return;
    }

    switch(kind) {
    case 1:
    case 42:
      evaluatedContent = expandMentions(content, tempChildEventsMap);
      if( gShowLnInvoicesAsQr) {
        evaluatedContent = expandLNInvoices(evaluatedContent);
      }
      if( translator != null && gTranslate && !evaluatedContent.isEnglish()) {
        if( gDebug > 0) print("found that this comment is non-English: $evaluatedContent");

        // only translate for latest events
        if( DateTime.fromMillisecondsSinceEpoch(createdAt *1000).compareTo( DateTime.now().subtract(Duration(days:gNumTranslateDays)) ) > 0 ) {
          if( gDebug > 0) print("Sending google request: translating $content");
          if( translator != null) {
            try {
            numEventsTranslated++;
            translator?.translate(content, to: 'en')
                       .then( (result) => { evaluatedContent =   "$evaluatedContent\n\nTranslation: ${result.toString()}" , if( gDebug > 0)  print("Google translate returned successfully for one call.")} )
                       .onError((error, stackTrace)  { 
                            if( gDebug > 0) print("Translate error = $error\n for  content = $content\n");
                            return {} ;
                          }
                        );
            } on Exception catch(err) {
              if( gDebug >= 0) print("Info: Error in trying to use google translate: $err");
            }
          }
        }
      }
    break;

    } // end switch
    return;
  } // end translateAndExpandMentions

  // is called only once for each event received ( or read from file)
  String? TranslateAndDecryptGroupInvite() {

    if (content == "" ||  evaluatedContent != "") {
      return null;
    }

    switch(kind) {
    case gSecretMessageKind: 
      if( userPrivateKey == ""){ // cant process if private key not given
        return null;
      }

      if(!isValidDirectMessage(this, acceptableKind: kind)) {
        return null;
      }

      String? decrypted = decryptDirectMessage();
      if( decrypted != null) {
        evaluatedContent = decrypted;
      }
      return id;
    } // end switch

    return null;
  } // end TranslateAndDecryptGroupInvite

  // is called only once for each event received ( or read from file)
  void translateAndDecryptKind4(Map<String, Tree> tempChildEventsMap) {
    if( id == gCheckEventId) {
      printInColor("in translateAndDecryptKind4: decoding $gCheckEventId\n", redColor);
    }

    if (content == "" ||  evaluatedContent != "") {
      if( id == gCheckEventId) {
        printInColor("in translateAndDecryptKind4: returning \n", redColor);
      }
      return;
    }

    switch(kind) {
    case 4: 
      if( userPrivateKey == ""){ // cant process if private key not given
        break;
      }
      //if( pubkey == userPublicKey )  break; // crashes right now otherwise 
      if(!isValidDirectMessage(this)) {
        break;
      }

      if( id == gCheckEventId) {
        printInColor("in translateAndExpandMensitons: gonna decrypt \n", redColor);
      }

      //log.info("decrypting a message of kind 4");

      String? decrypted = decryptDirectMessage();
      if( decrypted != null) {
        evaluatedContent = decrypted;
        evaluatedContent = expandMentions(evaluatedContent, tempChildEventsMap);
      }
      //print("evaluatedContent: $evaluatedContent");
      break;
    } // end switch
  } // end translateAndExpandMentions


  // is called only once for each event received ( or read from file)
  void translateAndDecrypt14x(Set<String> secretMessageIds, List<Channel> encryptedChannels, Map<String, Tree> tempChildEventsMap) {
    if( id == gCheckEventId) {
      //printInColor("in translateAndExpand14x: decoding ee810ea73072af056cceaa6d051b4fcce60739247f7bcc752e72fa5defb64f09\n", redColor);
    }

    if (content == "" ||  evaluatedContent != "") {
      if( id == gCheckEventId) {
        //printInColor("in translateAndExpand14x: returning \n", redColor);
      }
      return;
    }

    if( createdAt < getSecondsDaysAgo(3)) {
      //print("old 142. not decrypting");
      //return;
    } 

    switch(kind) {
    case 142:
      //print("in translateAndDecrypt14x");
      Channel? channel = getChannelForMessage( encryptedChannels, id); 
      if( channel == null) {
        break;
      }

      if(!channel.participants.contains(userPublicKey)) {
        break;
      }

      if(!channel.participants.contains(pubkey)) {
        break;
      }

      String? decrypted = decryptEncryptedChannelMessage(secretMessageIds, tempChildEventsMap);
      if( decrypted != null) {
        //printWarning("Successfully decrypted kind 142: $id");
        evaluatedContent = decrypted;
        //print("in translateAndDecrypt14x: calling expandMentions");
        evaluatedContent = expandMentions(evaluatedContent, tempChildEventsMap);
        //print("content = $content");
        //print(evaluatedContent);
      }
      break;
    default:
      break;

    } // end switch
  } // end translateAndExpand14x


  String? decryptDirectMessage() {
    int ivIndex = content.indexOf("?iv=");
    if( ivIndex > 0) {
      var iv = content.substring( ivIndex + 4, content.length);
      var encStr = content.substring(0, ivIndex);

      String userKey = userPrivateKey ;
      String otherUserPubKey = "02$pubkey";
      if( pubkey == userPublicKey) { // if user themselve is the sender change public key used to decrypt
        userKey =  userPrivateKey;
        int numPtags = 0;
        for (var tag in tags) {
          if(tag[0] == "p" ) {
            otherUserPubKey = "02${tag[1]}";
            numPtags++;
          }
        } 
        // if there are more than one p tags, we don't know who its for
        if( numPtags != 1) {
          if( gDebug >= 0) printInColor(" in translateAndExpand: got event $id with number of p tags != one : $numPtags . not decrypting", redColor);
            return null;
        }
      } 

      var decrypted = myPrivateDecrypt( userKey, otherUserPubKey, encStr, iv); // use bob's privatekey and alic's publickey means bob can read message from alic
      return decrypted;
    } else {
      if(gDebug > 0) print("Invalid content for dm, could not get ivIndex: $content");
      return null;
    }
  }

  Channel? getChannelForMessage(List<Channel>? listChannel, String messageId) {
    if( listChannel == null) {
      return null;
    }
     for(int i = 0; i < listChannel.length; i++) {
      if( listChannel[i].messageIds.contains(messageId)) {
        return listChannel[i];
      }
     }
     return null;
  }
  

  String? decryptEncryptedChannelMessage(Set<String> secretMessageIds, Map<String, Tree> tempChildEventsMap) {

    if( id == "865c9352de11a3959c06fce5350c5a1b9fa0475d3234078a1bb45d152b370f0b") {  // known issue
      return null;
    }

    int ivIndex = content.indexOf("?iv=");
    if( ivIndex == -1) {
      return null;
    }
    var iv = content.substring( ivIndex + 4, content.length);
    var encStr = content.substring(0, ivIndex);
        
    String channelId = getChannelIdForKind4x();
    List<String> keys = [];
    keys = getEncryptedChannelKeys(secretMessageIds, tempChildEventsMap, channelId);

    if( keys.length != 2) {
      //printWarning("\nCould not get keys for event id: $id and channelId: $channelId\n");
      //print("keys = $keys\n\n");
      return null;
    }

    String priKey = keys[0];
    String pubKey = "02${keys[1]}";

    var decrypted = myPrivateDecrypt( priKey, pubKey, encStr, iv); // use bob's privatekey and alic's publickey means bob can read message from alic
    return decrypted;
  }

  // only applicable for kind 42/142 event; returns the channel 40/140 id of which the event is part of
  String getChannelIdForKind4x() {
    if( kind != 42 && kind != 142 && kind!=141) {
      return "";
    }

    // get first e tag, which should be the channel of which this is part of
    for( int i = 0; i < eTags.length; i++) {
      List tag = eTags[i];
      if( tag.isNotEmpty) {
        return tag[0];
      }
    }
    return '';
  }

  String getChannelIdForTTagRoom(String tagValue) {
    return "$tagValue #t";
  }

  // only applicable for kind 42/142 event; returns the channel 40/140 id of which the event is part of
  String getChannelIdForLocationRooms() {
    String ? location = getSpecificTag("location");

    if( kind == 1 &&  location != null && location != "") {
      return location +  gLocationTagIdSuffix;
    }
    return '';
  }


  // prints event data in the format that allows it to be shown in tree form by the Tree class
  void printEventData(int depth, bool topPost, Map<String, Tree>? tempChildEventsMap, Set<String>? secretMessageIds, List<Channel>? encryptedChannels) {
    if( !(kind == 1 || kind == 4 || kind == 42)) {
      return; // only print kind 1 and 42 and 4
    }

    // will only do decryption if its not been decrypted yet by looking at 'evaluatedContent'
    if( tempChildEventsMap != null )
    if(kind == 4) {
      translateAndDecryptKind4( tempChildEventsMap);
    } else if ([1, 42].contains(kind)) {
      translateAndExpandMentions(tempChildEventsMap);
    } else if ([142].contains(kind)) {
      if( secretMessageIds != null && encryptedChannels != null) {
        translateAndDecrypt14x( secretMessageIds, encryptedChannels, tempChildEventsMap);
      }
    }


    int n = gEventLenPrinted; // is 6 
    String maxN(String v)       => v.length > n? v.substring(0,n) : v.substring(0, v.length);

    String name = getAuthorName(pubkey, maxDisplayLen: gNameLengthInPost);    
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

    String commentColor = "";
    if( isNotification) {
      commentColor = gNotificationColor;
      isNotification = false;
    } else {
      commentColor = gCommentColor;
    }

    int tempEffectiveLen = name.length < gNameLengthInPost? name.length: gNameLengthInPost;
    name = name.substring(0,tempEffectiveLen);

    int effectiveNameFieldLen = gNameLengthInPost + 3;  // get this before name is mangled by color
    String nameColor = getNameColor(pubkey);

    // pad name to left 
    name = name.padLeft(gNameLengthInPost);
    name = name.substring(0, gNameLengthInPost);
    name = getStrInColor(name, nameColor);
    
    String strToPrint = "";
    if(!topPost) {
      strToPrint += "\n";
      strToPrint += getDepthSpaces(depth);
      strToPrint += " "; // in place of block for top posts
    } else {
      strToPrint += getDepthSpaces(depth);
      strToPrint += "█";
    }

    strToPrint += "$name: ";
    const int typicalxLen = "|id: 82b5 , 12:04 AM Sep 19".length + 5; // not sure where 5 comes from 
    List<dynamic> reactionString = getReactionStr(depth);
    //print("\n|${reactionString[0]}|\n ${  reactionString[1]}\n }");
    String idDateLikes = "    |id: ${maxN(id)}, $strDate ${reactionString[0]}" ;
    idDateLikes = idDateLikes.padRight(typicalxLen);

    String temp = tempEvaluatedContent==""?tempContent: tempEvaluatedContent;
    String contentShifted = makeParagraphAtDepth( temp,  gSpacesPerDepth * depth + effectiveNameFieldLen);
    
    int maxLineLen =  gTextWidth - gSpacesPerDepth * depth -  effectiveNameFieldLen ;
    int lastLineLen = contentShifted.length;
    int i = 0;

    contentShifted = contentShifted.trim();

    // find the effective length of the last line of the content
    for(i = contentShifted.length - 1; i >= 0; i-- ) {
      if( contentShifted[i] == "\n") {
        break;
      }
    }

    if( i >= 0 && contentShifted[i] == "\n") {
      lastLineLen = contentShifted.length - i;
    }

    // effective len of last line is used to calcluate where the idDateLikes str is affixed at the end 
    int effectiveLastLineLen = lastLineLen - gSpacesPerDepth * depth - effectiveNameFieldLen - gNumLeftMarginSpaces;
    if( contentShifted.length <= maxLineLen ) {
      effectiveLastLineLen = contentShifted.length;
    }

    // needed to use this because the color padding in notifications reactions will mess up the length calculation in the actual reaction string
    int colorStrLen = reactionString[0].length -  reactionString[1];

    // now actually find where the likesDates string goes
    if( (gSpacesPerDepth * depth + effectiveNameFieldLen + effectiveLastLineLen + idDateLikes.length ) <= gTextWidth) {
      idDateLikes =  idDateLikes.padLeft((gTextWidth ) + colorStrLen - (gSpacesPerDepth * depth + effectiveNameFieldLen + effectiveLastLineLen));
    } else {
      idDateLikes =   "\n${idDateLikes.padLeft(gNumLeftMarginSpaces + gTextWidth + colorStrLen)}";
    }

    // print content and the dateslikes string
    strToPrint += getStrInColor("$contentShifted$idDateLikes\n", commentColor);
    stdout.write(strToPrint);
  }

  String getAsLine(var tempChildEventsMap, Set<String>? secretMessageIds, List<Channel>? encryptedChannels, {int len = 20}) {

    // will only do decryption if its not been decrypted yet by looking at 'evaluatedContent'
    if(kind == 4) {
      translateAndDecryptKind4( tempChildEventsMap);
    } else if ([1, 42].contains(kind)) {
      translateAndExpandMentions(tempChildEventsMap);
    } else if ([142].contains(kind)) {
      if( tempChildEventsMap != null && secretMessageIds != null && encryptedChannels != null) {
        translateAndDecrypt14x(secretMessageIds, encryptedChannels, tempChildEventsMap);
      }
    }

    String contentToPrint = evaluatedContent.isEmpty? content: evaluatedContent;
    if( len == 0 || len > contentToPrint.length) {
      //len = contentToPrint.length;
    }

    contentToPrint = contentToPrint.replaceAll("\n", " ");
    contentToPrint = contentToPrint.replaceAll("\r", " ");
    contentToPrint = contentToPrint.replaceAll("\t", "  ");
    contentToPrint = contentToPrint.padRight(len).substring(0, len);
    //contentToPrint = contentToPrint.padRight(len);
    String strToPrint = '$contentToPrint   - ${getAuthorName(pubkey, maxDisplayLen: gNameLengthInPost).padLeft(12)}';

    String paddedStrToPrint = strToPrint;
    
    if( isNotification) {
      paddedStrToPrint = "$gNotificationColor$paddedStrToPrint$gColorEndMarker";
      isNotification = false;
    }
    //print("returning $paddedStrToPrint");
    return paddedStrToPrint;
  }


  String getStrForChannel(int depth, Map<String, Tree> tempChildEventsMap, Set<String>? secretMessageIds, List<Channel>? encryptedChannels) {

    // will only do decryption if its not been decrypted yet by looking at 'evaluatedContent'
     // will only do decryption if its not been decrypted yet by looking at 'evaluatedContent'
    if(kind == 4) {
      translateAndDecryptKind4( tempChildEventsMap);
    } else if ([1, 42].contains(kind)) {
      translateAndExpandMentions(tempChildEventsMap);
    } else if ([142].contains(kind)) {
      if( secretMessageIds != null && encryptedChannels != null) {
        //print('decrypting 14x in getStrForChannel');
        translateAndDecrypt14x(secretMessageIds, encryptedChannels, tempChildEventsMap);
      }
    }

    String strToPrint = "";
    String name = getAuthorName(pubkey, maxDisplayLen: gNameLengthInPost);    
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

    if( tempEvaluatedContent=="") {
      tempEvaluatedContent = tempContent;
    }

    const int nameWidthDepth = 16~/gSpacesPerDepth; // how wide name will be in depth spaces
    const int timeWidthDepth = 18~/gSpacesPerDepth;
    int nameWidth = gSpacesPerDepth * nameWidthDepth;
    
    // get name in color and pad it too
    String nameToPrint = name.padLeft(nameWidth).substring(0, nameWidth);
    nameToPrint = getStrInColor(nameToPrint, getNameColor(pubkey));

    String dateToPrint = strDate.padLeft(gSpacesPerDepth * timeWidthDepth).substring(0, gSpacesPerDepth * timeWidthDepth);
    
    // depth above + ( depth numberof spaces = 1) + (depth of time = 2) + (depth of name = 3)
    int contentDepth = depth + 1 + timeWidthDepth + nameWidthDepth;
    int magicNumberDepth6 = 2; // magic number for gSpacesPerDepth == 6
    int finalContentDepthInSpaces = gSpacesPerDepth * contentDepth + magicNumberDepth6;
    int contentPlacementColumn = finalContentDepthInSpaces + gNumLeftMarginSpaces;

    String contentShifted = makeParagraphAtDepth(tempEvaluatedContent, finalContentDepthInSpaces);

    Event? replyToEvent = getReplyToChannelEvent(tempChildEventsMap);
    String strReplyTo = "";
    if( replyToEvent != null) {
      //print("in getStrForChannel: got replyTo id = ${replyToEvent.eventData.id}");
      if( replyToEvent.eventData.kind == 1 || replyToEvent.eventData.kind == 42 || replyToEvent.eventData.kind == 142) { // make sure its a kind 1 or 40 message
        if( replyToEvent.eventData.id != id) { // basic self test

          // quote only a part of the reply if its too long. add ellipsis if requried.          
          String replyToPrint = "";
          if( replyToEvent.eventData.evaluatedContent.length <= gReplyLengthPrinted){
             replyToPrint = replyToEvent.eventData.evaluatedContent;
          } else {
            replyToPrint = "${replyToEvent.eventData.evaluatedContent.substring(0, gReplyLengthPrinted)}...";
          }
          strReplyTo = 'In reply to:"${getAuthorName(replyToEvent.eventData.pubkey)}: $replyToPrint"';
          strReplyTo = makeParagraphAtDepth(strReplyTo, finalContentDepthInSpaces + 6); // one extra for content
          
          // add reply to string to end of the content. How it will show:
          contentShifted += ( "\n${getNumSpaces( contentPlacementColumn + gSpacesPerDepth)}$strReplyTo"); 
        }
      }
    } else {
      //printWarning("no reply to event for event id $id");
    }
   
    String msgId = id.substring(0, 3).padLeft(gSpacesPerDepth~/2).padRight(gSpacesPerDepth) ;

    if( isNotification) {
      strToPrint = "$gNotificationColor${getDepthSpaces(depth-1)}$msgId  $dateToPrint    $nameToPrint: $gNotificationColor$contentShifted$gColorEndMarker";
      isNotification = false;
    } else {
      strToPrint = "${getDepthSpaces(depth-1)}$msgId  $dateToPrint    $nameToPrint: $contentShifted";
    }
    return strToPrint;
  }

  // looks up global map of reactions, if this event has any reactions, and then prints the reactions
  // in appropriate color( in case one is a notification, which is stored in member variable)
  // returns the string and its length in a dynamic list
  List<dynamic> getReactionStr(int depth) {
    String reactorNames = "";

    int len = 0;

    if( isHidden  ||  isDeleted) {
      return ["",0];
    }

    if( gReactions.containsKey(id)) {
      reactorNames = "Likes: ";
      len = reactorNames.length;
      int numReactions = gReactions[id]?.length??0;
      List<List<String>> reactors = gReactions[id]??[];
      bool firstEntry = true;
      for( int i = 0; i <numReactions; i++) {
        
        String comma = (firstEntry)?"":", ";
        String authorName = "";

        String reactorId = reactors[i][0];
        if( newLikes.contains(reactorId) && reactors[i][1] == "+") {
          // this is a notifications, print it and then later empty newLikes
          authorName = getAuthorName(reactorId);
          reactorNames += comma + gNotificationColor + authorName + gColorEndMarker + gCommentColor ; // restart with comment color because this is part of ongoing print
          len += 2 + authorName.length;
          firstEntry = false;
        } else {
          // this is normal printing of the reaction. only print for + for now
          if( reactors[i][1] == "+") {
            authorName = getAuthorName(reactorId);
          }
            reactorNames += comma + authorName;
            len += (2 + authorName.length);
            firstEntry = false;
        }


      } // end for

      // if at least one entry as colored notification was made
      if( firstEntry == false) {
        reactorNames += gColorEndMarker;
      }

      newLikes.clear();
      reactorNames += "";
    }
    return [reactorNames, len];
  }

  // returns the last e tag as reply to event for kind 42 and 142 events
  Event? getReplyToChannelEvent(Map<String, Tree> tempChildEventsMap) {
    switch (kind) {
      case 42:
      case 142:
      for(int i = tags.length - 1; i >= 0; i--) {
        List tag = tags[i];
        if( tag[0] == 'e') {
          String replyToEventId = tag[1];
          Event? eventInReplyTo = (gStore?.allChildEventsMap[replyToEventId]?.event);
          if( eventInReplyTo != null) {
            // add 1 cause 42 can reply to or tag kind 1, and we'll show that kind 1
            if ( [1,42,142].contains( eventInReplyTo.eventData.kind)) { 
              return eventInReplyTo;
            }
          }
        }
      }
      break;
      case 1:
        String replyToId = getParent(tempChildEventsMap);
        return tempChildEventsMap[replyToId]?.event;
    } // end of switch
    return null;
  } // end getReplyToChannelEvent() 
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
      if( d.length > gMaxEventLenthAccepted) {
        //throw Exception("Event json is larger than max len");

      }

      dynamic json = jsonDecode(d);

      if( json.length < 3) {
        String e = "";
        e = json.length > 1? json[0]: "";
        if( gDebug > 0) {
          print("Could not create event. json.length = ${json.length} string d= $d $e");
        }
        throw Exception("Event json has less than 3 elements");
      }

      EventData newEventData = EventData.fromJson(json[2]);
      if( !fromFile) {
        newEventData.isNotification = true;
      }
      return Event(json[0] as String, json[1] as String, newEventData, [relay], d, fromFile );
    } on Exception catch(e) {
      if( gDebug > 0) {
        print("Could not create event. $e\nproblem str: $d\n");
      }
      rethrow;
    }
  }

  void printEvent(int depth, bool topPost) {
    eventData.printEventData(depth, topPost, null, null, null);
    //stdout.write("\n$originalJson --------------------------------\n\n");
  }

  @override 
  String toString() {
    return '$eventData     Seen on: ${seenOnRelays[0]}\n';
  }
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
        if( contacts[i].contactPubkey == contactPubkey) {
          relay = contacts[i].relay;
          return relay;
        }
      }
    }
  }
  // if not found return empty string
  return relay;
}

// https://codewithandrea.com/articles/flutter-exception-handling-try-catch-result-type/
Future<http.Response> fetchNip05Info(String nip05Url) {
  http.Response resp404 = http.Response.bytes([], 404);

  try {
    return http.get(Uri.parse(nip05Url));
  } catch(ex) {
    return Future.value(resp404);
  }
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
  String lud06 = "";
  String lud16 = "";
  String displayName = "";
  String website = "";
  String nip05 = "";

  try {
    dynamic json = jsonDecode(content);
    name = json["name"]??"";
    about = json["about"]??"";    
    picture = json["picture"]??"";    
    lud06 = json["lud06"]??"";    
    lud16 = json["lud16"]??"";    
    displayName = json["display_name"]??"";    
    website = json["website"]??"";    
    nip05 = json['nip05']??"";
    //String twitterId = json['twitter']??"";
    //String githubId = json['github']??"";
  } catch(ex) {
    if( gDebug > 0) print("Error in processKind0Event: $ex for pubkey: ${e.eventData.pubkey}");
  }

  bool newEntry = false, entryModified = false;
  if( !gKindONames.containsKey(e.eventData.pubkey)) {    
    gKindONames[e.eventData.pubkey] = UserNameInfo(e.eventData.createdAt, name, about, picture, lud06, lud16, displayName, website, nip05, null);
    newEntry = true;
  } else {
    int oldTime = gKindONames[e.eventData.pubkey]?.createdAt??0;
    if( oldTime < e.eventData.createdAt) {
      gKindONames[e.eventData.pubkey] = UserNameInfo(e.eventData.createdAt, name, about, picture, lud06, lud16, displayName, website, nip05, null);
      entryModified = true;
    }
  }

  if(gDebug > 0) { 
    print("At end of processKind0Events: for pubkey ${e.eventData.pubkey} for name = $name ${newEntry? "added entry": ( entryModified?"modified entry": "No change done")} ");
  }

  bool localDebug = false; //e.eventData.pubkey == "9ec7a778167afb1d30c4833de9322da0c08ba71a69e1911d5578d3144bb56437"? true: false;

  if( newEntry || entryModified) {
    if(nip05.isNotEmpty) {
      List<String> urlSplit = nip05.split("@");
      if( urlSplit.length == 2) {
        
        String urlNip05 = "${urlSplit[1]}/.well-known/nostr.json?name=${urlSplit[0]}";
        if( !urlNip05.startsWith("http")) {
          urlNip05 = "http://$urlNip05";
        }

        fetchNip05Info(urlNip05)
          .then((httpResponse) { 
            if( localDebug ) print("-----\nnip future for $urlNip05 returned body ${httpResponse.body}");

            var namesInResponse;        
            try {
              dynamic json = jsonDecode(httpResponse.body);
              namesInResponse = json["names"];
              if( namesInResponse.length > 0) {
                for(var returntedName in namesInResponse.keys) {
                  
                  if( returntedName == urlSplit[0]  && namesInResponse[returntedName] == e.eventData.pubkey) {
                    int oldTime = 0;
                    if( !gKindONames.containsKey(e.eventData.pubkey)) {
                      //printWarning("in response handing. creating user info");
                      gKindONames[e.eventData.pubkey] = UserNameInfo(e.eventData.createdAt, name, about, picture, lud06, lud16, displayName, website,null, null);
                    } else {
                      oldTime = gKindONames[e.eventData.pubkey]?.createdAt??0;
                      //print("in response handing. user info exists with old time = $oldTime and this event time = ${e.eventData.createdAt}");
                    }

                    if( oldTime <= e.eventData.createdAt ) {
                      gKindONames[e.eventData.pubkey]?.nip05Verified = true;
                      gKindONames[e.eventData.pubkey]?.nip05Id = nip05;
                    }
                    return;
                  }
                }
              } else {
                //print("names = 0");
              }
            } catch(ex) {
            }
          }) 
          .catchError((e){if( gDebug > 0) print('in fetch nip caught error $e for url $urlNip05');});
      }
    }
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
    gKindONames[newContactEvent.eventData.pubkey] = UserNameInfo(null, null, null, null, null, null, null, null, null, newContactEvent, newContactEvent.eventData.createdAt);
    newEntry = true;
  } else {
    // if entry already exists, then check its old time and update only if we have a newer entry now
    int oldTime = gKindONames[newContactEvent.eventData.pubkey]?.createdAtKind3??0;
    if( oldTime < newContactEvent.eventData.createdAt) {
      int? createdAt = gKindONames[newContactEvent.eventData.pubkey]?.createdAt;
      String?   name = gKindONames[newContactEvent.eventData.pubkey]?.name, 
               about = gKindONames[newContactEvent.eventData.pubkey]?.about, 
             picture = gKindONames[newContactEvent.eventData.pubkey]?.picture,
               lud06 = gKindONames[newContactEvent.eventData.pubkey]?.lud06,
               lud16 = gKindONames[newContactEvent.eventData.pubkey]?.lud16,
               displayName = gKindONames[newContactEvent.eventData.pubkey]?.display_name,
               website = gKindONames[newContactEvent.eventData.pubkey]?.website,
             nip05id = gKindONames[newContactEvent.eventData.pubkey]?.nip05Id??"";
      
      gKindONames[newContactEvent.eventData.pubkey] = UserNameInfo(createdAt, name, about, picture, lud06, lud16, displayName, website, nip05id, newContactEvent, newContactEvent.eventData.createdAt );
      entryModified = true;
    }
  }

  if(gDebug > 0) { 
      print("At end of processKind3Events:  ${newEntry? "added entry": ( entryModified?"modified entry": "No change done")} ");
  }
  return newEntry || entryModified;
}

String getNip05Name( String pubkey) {
  String nip05name = "";
  if( gKindONames[pubkey]?.name == null || gKindONames[pubkey]?.name?.length == 0) {
    nip05name = "";
  }
  else {
    String name = gKindONames[pubkey]?.name??"";
    if( gKindONames[pubkey]?.nip05Verified??false) {
      nip05name = "$name (nip05: ${gKindONames[pubkey]?.nip05Id??""})";
    } else {
      nip05name = name;
    }
  }
  return nip05name;
}

// returns name by looking up global list gKindONames, which is populated by kind 0 events
String getAuthorName(String pubkey, {int maxDisplayLen = gMaxInteger, int pubkeyLenShown = 5}) {

  if( gFollowList.isEmpty)  {
    gFollowList = getFollows(userPublicKey);
  }
  bool isFollow = gFollowList.contains(pubkey) && (pubkey != userPublicKey);

  String maxLen(String pubkey) => pubkey.length > pubkeyLenShown? pubkey.substring(0,pubkeyLenShown) : pubkey.substring(0, pubkey.length);
  String name = "";
  if( gKindONames[pubkey]?.name == null || gKindONames[pubkey]?.name?.length == 0) {
    name = maxLen(pubkey);
  } else {
    name = (gKindONames[pubkey]?.name)??maxLen(pubkey);
  }

  // then add valid check mark in default follows 
  if( isFollow) {
    if( name.length >= maxDisplayLen ) {
      name = name.substring(0, maxDisplayLen-1) + gValidCheckMark;
    } else {
      name = name + gValidCheckMark;
    }
  } else {
    // remove this tick from other names
    name = name.replaceAll(gValidCheckMark, "");

  }

  return name;
}

// returns full public key(s) for the given username( which can be first few letters of pubkey, or the user name)
Set<String> getPublicKeyFromName(String inquiredName) {
  if( inquiredName.isEmpty) {
    return {};
  }
  Set<String> pubkeys = {};
  gKindONames.forEach((pubkey, userInfo) {
    // check both the user name, and the pubkey to search for the user
    // check username 
    if( userInfo.name != null) {
      int minNameLen = min( inquiredName.length, (userInfo.name?.length)??0);
      if( inquiredName.toLowerCase() == userInfo.name?.substring(0, minNameLen).toLowerCase()) {
        pubkeys.add(pubkey);
      }
    }

    // check public key
    if( inquiredName.length >= 2 &&  inquiredName.length <= pubkey.length) {
      if( pubkey.substring(0, inquiredName.length) == inquiredName) {
        pubkeys.add(pubkey);
      }
    }
  });

  return pubkeys;
}

// returns the seconds since epoch N days ago
int getSecondsDaysAgo( int N) {
  return  DateTime.now().subtract(Duration(days: N)).millisecondsSinceEpoch ~/ 1000;
}

// returns the seconds since epoch S seconds ago
int getTimeSecondsAgo( int S) {
  return  DateTime.now().subtract(Duration(seconds: S)).millisecondsSinceEpoch ~/ 1000;
}


// will write d tabs worth of space ( where tab width is in settings)
void printDepth(int d) {
  for( int i = 0; i < gSpacesPerDepth * d + gNumLeftMarginSpaces; i++) {
    stdout.write(" ");
  }
}

void printCenteredHeadline(displayName) {
  int numDashes = 10; // num of dashes on each side
  int startText = gNumLeftMarginSpaces + ( gTextWidth - (displayName.length + 2 * numDashes)) ~/ 2; 
  if( startText < 0) {
    startText = 0;
  }

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

// make a paragraph of s that starts at numSpaces ( from screen left), and does not extend beyond gTextWidth+gNumLeftMarginSpaces. break it, or add 
// a newline if it goes beyond gTextWidth + gNumLeftMarginSpaces
String makeParagraphAtDepth(String s, int depthInSpaces) {

  List<List<int>> urlRanges = getUrlRanges(s);
  
  String newString = "";
  String spacesString = getNumSpaces(depthInSpaces + gNumLeftMarginSpaces);

  int lenPerLine = gTextWidth - depthInSpaces;
  //print("In makeParagraphAtDepth: gNumLeftMarginSpaces = $gNumLeftMarginSpaces depthInSPaces = $depthInSpaces LenPerLine = $lenPerLine gTextWidth = $gTextWidth ");
  for(int startIndex = 0; startIndex < s.length; ) {
    List listCulledLine = getLineWithMaxLen(s, startIndex, lenPerLine, spacesString, urlRanges);

    String line = listCulledLine[0];
    int lenReturned = listCulledLine[1] as int;

    if( line.isEmpty || lenReturned == 0) break;

    newString += line;
    startIndex += lenReturned;
  }

  return newString;
}

// returns from string[startIndex:] the first len number of chars. no newline is added. 
List getLineWithMaxLen(String s, int startIndex, int lenPerLine, String spacesString, List<List<int>> urlRanges) {

  if( startIndex >= s.length) {
    return ["", 0];
  }

  String line = ""; // is returned
  
  // if length required is greater than the length of string remaing, return whatever remains
  int numCharsInLine = 0;

  int i = startIndex;
  // i indexes over the input line ( which is the whole comment)
  for(; i < startIndex + lenPerLine && i < s.length; i++) {
    line += s[i];
    numCharsInLine ++;

    if( s[i] == "\n") {
      i++;
      numCharsInLine = 0;
      line += spacesString;
      break;
    }
  }

  int urlEnd = 0;
  if( (urlEnd = isInRange(i, urlRanges)) != 0) {

    line = line + s.substring(i, urlEnd);
    i = urlEnd;

  } else {

    if( numCharsInLine > lenPerLine || ( (numCharsInLine == lenPerLine) && (s.length > startIndex + numCharsInLine) )) {
      bool lineBroken = false;

      // line is broken only if the returned line is the longest it can be, and
      // if its length is greater than the gMaxLenBrokenWord constant
      if( line.length >= lenPerLine &&  line.length > gMaxLenUnbrokenWord  ) {
        int i = line.length - 1;

        // find a whitespace character
        for( ; i > 0 && !isWordSeparater(line[i]); i--) {
           {}
        }
        // for ended 

        if( line.length - i  < gMaxLenUnbrokenWord) {

          // break the line here if its a word separator
          if( isWordSeparater(line[i])) {
            int newLineStart = i + 1;
            if( line[i] != ' ') {
              newLineStart = i;
            }
            line = "${line.substring(0, i)}\n$spacesString${line.substring(newLineStart, line.length)}";
            lineBroken = true;
          }
        }
      
      }

      if( !lineBroken ) {
        if( s.length > i ) {
          line += "\n";
          line += spacesString;
        }
      }
    }
  }
  return  [line, i - startIndex];
}


// The contact only stores id and relay of contact. The actual name is stored in a global variable/map
class Contact implements Comparable<Contact> {
  String contactPubkey, relay;
  Contact(this.contactPubkey, this.relay);

  @override 
  String toString() {
    return 'id: $contactPubkey ( ${getAuthorName(contactPubkey)})     relay: $relay';
  }

  @override
  int compareTo(Contact other) {
    return getAuthorName(contactPubkey).compareTo(getAuthorName(other.contactPubkey));
  }
}

String getShaId(String pubkey, String createdAt, String kind, String strTags, String content) {
  String buf = '[0,"$pubkey",$createdAt,$kind,[$strTags],"$content"]';
  if(gSpecificDebug > 0) print("in getShaId for buf: |$buf|");
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
 * Returns true if this is a valid direct message to just this user. Direct message = kind 4 AND 104
 */
bool isValidDirectMessage(EventData directMessageData, {int acceptableKind = 4}) {

  if( acceptableKind != directMessageData.kind) {
    return false;
  }

  bool validUserMessage = false;
  List<String> allPtags = [];

  for (var tag in directMessageData.tags) {
    if( tag.length < 2 ) {
      continue;
    }
    if( tag[0] == "p" && tag[1].length == 64) { // basic length sanity test
      allPtags.add(tag[1]);
    }
  }

  if(gDebug >= 0 && gCheckEventId == directMessageData.id) print("In isvalid direct message: ptags len: ${allPtags.length}, ptags = $allPtags");

  if( directMessageData.pubkey == userPublicKey && allPtags.length == 1) {
    if( allPtags[0].substring(0, 32) != "0".padLeft(32, '0')) { // check that the message hasn't been sent to an invalid pubkey
      validUserMessage = true; // case where this user is sender
    }
  } else {
    if(gCheckEventId == directMessageData.id) print("in else case 3");
    if ( directMessageData.pubkey != userPublicKey) {
      if(gDebug > 0 && gCheckEventId == directMessageData.id) print("in if 5 allpags 1st = ${allPtags[0]} userPUblic key = $userPublicKey");
      if( allPtags.length == 1 && allPtags[0] == userPublicKey) {

        validUserMessage = true; // case where this user is recipeint 
      }
    }
  }
  return validUserMessage;
}

String getRandomPrivKey() {
  FortunaRandom fr = FortunaRandom();
  final sGen = Random.secure();
  fr.seed(KeyParameter(
      Uint8List.fromList(List.generate(32, (_) => sGen.nextInt(255)))));

  BigInt randomNumber = fr.nextBigInteger(256);
  String strKey = randomNumber.toRadixString(16);
  if( strKey.length < 64) {
    int numZeros = 64 - strKey.length;
    for(int i = 0; i < numZeros; i++) {
      strKey = "0$strKey";
    }
  }
  return strKey;
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
      byteSecret = Kepler.byteSecret(privateString, publicString);
      gMapByteSecret[publicString] = byteSecret;
    }

    final secretIV = byteSecret;
    final key = Uint8List.fromList(secretIV[0]);
    final iv = b64IV.length > 6
              ? convert.base64.decode(b64IV)
              : Uint8List.fromList(secretIV[1]);

    CipherParameters params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv), null);

    PaddedBlockCipherImpl cipherImpl = PaddedBlockCipherImpl(
        PKCS7Padding(), CBCBlockCipher(AESEngine()));

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
    return  finalPlainText.sublist(0, offset);
  } catch(e) {
      if( gDebug >= 0) print("Decryption error =  $e");
      return Uint8List(0);
  }
}

// Encrypt data using self private key in nostr format ( with trailing ?iv=)
String myEncrypt( String privateString, 
                         String publicString, 
                         String plainText) {
  Uint8List uintInputText = convert.Utf8Encoder().convert(plainText);
  final encryptedString = myEncryptRaw(privateString, publicString, uintInputText);
  return encryptedString;
}

String myEncryptRaw( String privateString, 
                     String publicString, 
                     Uint8List uintInputText) {
  final secretIV = Kepler.byteSecret(privateString, publicString);
  final key = Uint8List.fromList(secretIV[0]);

  // generate iv  https://stackoverflow.com/questions/63630661/aes-engine-not-initialised-with-pointycastle-securerandom
  FortunaRandom fr = FortunaRandom();
  final sGen = Random.secure();
  fr.seed(KeyParameter(
                      Uint8List.fromList(List.generate(32, (_) => sGen.nextInt(255)))));
  final iv = fr.nextBytes(16);
   
  CipherParameters params = PaddedBlockCipherParameters(
                                                            ParametersWithIV(KeyParameter(key), iv), null);

  PaddedBlockCipherImpl cipherImpl = PaddedBlockCipherImpl(
                                                            PKCS7Padding(), CBCBlockCipher(AESEngine()));

  cipherImpl.init(true,  // means to encrypt
                  params as PaddedBlockCipherParameters<CipherParameters?,
                                                        CipherParameters?>);
  
  // allocate space
  final Uint8List  outputEncodedText = Uint8List(uintInputText.length + 16);

  var offset = 0;
  while (offset < uintInputText.length - 16) {
    offset += cipherImpl.processBlock(uintInputText, offset, outputEncodedText, offset);
  }

  //add padding 
  offset += cipherImpl.doFinal(uintInputText, offset, outputEncodedText, offset);
  final Uint8List finalEncodedText = outputEncodedText.sublist(0, offset);

  String stringIv = convert.base64.encode(iv);
  String outputPlainText = convert.base64.encode(finalEncodedText);
  outputPlainText = "$outputPlainText?iv=$stringIv";
  return  outputPlainText;
}

/// Read events from file. a flag is set for such events, so that when writing events back, the ones read from file aren't added, and only
/// new events from relays are written to file.
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
    if( gDebug > 0) print("Could not open file. error =  $e");
  }

  if( gDebug > 0) print("In readEventsFromFile: returning ${events.length} total events");
  return events;
}


List<String> getEncryptedChannelKeys(Set<String> inviteMessageIds, Map<String, Tree> tempChildEventsMap, String channelId) {
  Event? e = tempChildEventsMap[channelId]?.event;
  if( e != null) {

    for( String inviteMessageid in inviteMessageIds) {
      Event? messageEvent = tempChildEventsMap[inviteMessageid]?.event;
      if( messageEvent != null) {
        String evaluatedContent = messageEvent.eventData.evaluatedContent;
        if( evaluatedContent.startsWith("App Encrypted Channels:")) {
          if( evaluatedContent.contains(channelId) && evaluatedContent.length == 288) {
            String priKey = evaluatedContent.substring(159, 159 + 64);
            String pubKey = evaluatedContent.substring(224, 224 + 64);

            if( priKey.length == 64 && pubKey.length == 64) {
              return [priKey, pubKey];
            }
          }
        }
      } else {
        print("could not get message event");
      }
    }
  }
  return [];
}

String myGetPublicKey(String prikey) {
  String pubkey = getPublicKey(prikey);

  if( pubkey.length < 64) {
    int numZeros = 64 - pubkey.length;
    for(int i = 0; i < numZeros; i++) {
      pubkey = "0$pubkey";
    }
  }
  return pubkey;
}
