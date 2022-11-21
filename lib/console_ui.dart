import 'dart:io';
import 'dart:convert';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:nostr_console/settings.dart';
import 'package:bip340/bip340.dart';

Future<void> processAnyIncomingEvents(Store node, [bool printNotifications = true])  async {
  reAdjustAlignment();

  // need a bit of wait to give other events to execute, so do a delay, which allows
  // relays to recieve and handle new events
  const int waitMilliSeconds = 200;
  Future.delayed(const Duration(milliseconds: waitMilliSeconds), ()  {
    
    Set<String> newEventIdsSet = node.processIncomingEvent(getRecievedEvents());
    clearEvents();

    String nameToDisplay = userPrivateKey.length == 64? 
                              "$gCommentColor${getAuthorName(userPublicKey)}$gColorEndMarker": 
                              "${gWarningColor}You are not signed in$gColorEndMarker but are using public key $userPublicKey";
    
    if( printNotifications) {
      node.printNotifications(newEventIdsSet, nameToDisplay);
    }
  });

  
  Future<void> foo() async {
    await Future.delayed(Duration(milliseconds: waitMilliSeconds));
    return;
  }
  await foo();
  
}

String mySign(String privateKey, String msg) {
  String randomSeed = getRandomPrivKey();
  randomSeed = randomSeed.substring(0, 32);
  return sign(privateKey, msg, randomSeed);
}


/* @function sendReplyPostLike Used to send Reply, Post and Like ( event 1 for reply and post, and event 7 for like/reaction)
 * If replyToId is blank, then it does not reference any e/p tags, and thus becomes a top post
 * otherwise e and p tags are found for the given event being replied to, if that event data is available
 */
Future<void> sendReplyPostLike(Store node, String replyToId, String replyKind, String content) async {
  content = addEscapeChars(content);
  String strTags = node.getTagStr(replyToId, exename, true);
  if( replyToId.isNotEmpty && strTags == "") { // this returns empty only when the given replyto ID is non-empty, but its not found ( nor is it 64 bytes)
    print("${gWarningColor}The given target id was not found and/or is not a valid id. Not sending the event.$gColorEndMarker"); 
    return; 
  }

  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
  String id = getShaId(userPublicKey, createdAt.toString(), replyKind, strTags, content);

  // generate POW if required
  String vanityTag = strTags;
  if (replyKind == "1" && gDifficulty > 0) {
    if( gDebug > 0) log.info("Starting pow");

    int numBytes = (gDifficulty % 4 == 0)? gDifficulty ~/ 4: gDifficulty ~/ 4 + 1;
    String zeroString = "";
    for( int i = 0; i < numBytes; i++) {
      zeroString += "0";
    }

    int numShaDone = 0;
    for( numShaDone = 0; numShaDone < 100000000; numShaDone++) {
      vanityTag = strTags + ',["nonce","$numShaDone","$gDifficulty"]';
      id = getShaId(userPublicKey, createdAt.toString(), replyKind, vanityTag, content);
      if( id.substring(0, numBytes) == zeroString) {
        break;
      }
    }

    if( gDebug > 0) log.info("Ending pow numShaDone = $numShaDone id = $id");
  }

  String sig = mySign(userPrivateKey, id);
  
  String toSendMessage = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":$replyKind,"tags":[$vanityTag],"content":"$content","sig":"$sig"}]';
  sendRequest( gListRelayUrls1, toSendMessage);
}

// Sends a public channel message
Future<void> sendChannelMessage(Store node, Channel channel, String messageToSend, String replyKind) async {
  messageToSend = addEscapeChars(messageToSend);

  String strTags = node.getTagStrForChannel(channel, exename);
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
  
  String id = getShaId(userPublicKey, createdAt.toString(), replyKind, strTags, messageToSend);
  String sig = mySign(userPrivateKey, id);

  String toSendMessage = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":$replyKind,"tags":[$strTags],"content":"$messageToSend","sig":"$sig"}]';
  //printInColor(toSendMessage, gCommentColor);
  sendRequest( gListRelayUrls1, toSendMessage);

  Future<void> foo() async {
    await Future.delayed(Duration(milliseconds: 300));
    return;
  }
  await foo();

}

// Sends a public channel message
Future<void> sendChannelReply(Store node, Channel channel, String replyTo, String messageToSend, String replyKind) async {

  messageToSend = addEscapeChars(messageToSend);

  String strTags = node.getTagStrForChannelReply(channel, replyTo, exename);
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
  
  String id = getShaId(userPublicKey, createdAt.toString(), replyKind, strTags, messageToSend);
  String sig = mySign(userPrivateKey, id);

  String toSendMessage = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":$replyKind,"tags":[$strTags],"content":"$messageToSend","sig":"$sig"}]';
  //printInColor(toSendMessage, gCommentColor);
  sendRequest( gListRelayUrls1, toSendMessage);

  Future<void> foo() async {
    await Future.delayed(Duration(milliseconds: 300));
    return;
  }
  await foo();

}

// send DM
Future<void> sendDirectMessage(Store node, String otherPubkey, String messageToSend) async {
  //messageToSend = addEscapeChars(messageToSend); since this get encrypted , it does not need escaping
  String otherPubkey02 = "02" + otherPubkey;
  String encryptedMessageToSend =        myEncrypt(userPrivateKey, otherPubkey02, messageToSend);

  String replyKind = "4";
  String strTags = '["p","$otherPubkey"]';
  strTags += gWhetherToSendClientTag?',["client","nostr_console"]':'';
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;

  String id = getShaId(userPublicKey, createdAt.toString(), replyKind, strTags, encryptedMessageToSend);
  String sig = mySign(userPrivateKey, id);
  String eventStrToSend = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":$replyKind,"tags":[$strTags],"content":"$encryptedMessageToSend","sig":"$sig"}]';
  //print("calling send for str : $eventStrToSend");
  sendRequest( gListRelayUrls1, eventStrToSend);

  Future<void> foo() async {
    await Future.delayed(Duration(milliseconds: 300));
    return;
  }
  await foo();
}

// sends event e; used to send kind 3 event; can send other kinds too like channel create kind 40, or kind 0
// does not honor tags mentioned in the Event, excpet if its kind 3, when it uses contact list to create tags
Future<String> sendEvent(Store node, Event e) async {
  String strTags = "";
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
  String content = addEscapeChars( e.eventData.content);

  // read the contacts and make them part of the tags, and then the sha
  if( e.eventData.kind == 3) {
    strTags = ""; // only new contacts will be sent
    for(int i = 0; i < e.eventData.contactList.length; i++) {
      String relay = e.eventData.contactList[i].relay;
      if( relay == "") {
        relay = defaultServerUrl;
      }

      String comma = ",";
      if( i == e.eventData.contactList.length - 1) {
        comma = "";
      }
      String strContact = '["p","${e.eventData.contactList[i].id}","$relay"]$comma';
      strTags += strContact;
    }
    
    // strTags += '["client","nostr_console"]';
  } else {
    strTags += '["client","nostr_console"]';
  }

  String id = getShaId(userPublicKey, createdAt.toString(), e.eventData.kind.toString(), strTags, content);
  String sig = mySign(userPrivateKey, id);

  String toSendMessage = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":${e.eventData.kind.toString()},"tags":[$strTags],"content":"$content","sig":"$sig"}]';
  //print("in send event: calling sendrequest for string \n $toSendMessage");
  sendRequest(gListRelayUrls1, toSendMessage);

  Future<void> foo() async {
    await Future.delayed(Duration(milliseconds: 500));
    return;
  }
  await foo();
  return id;
}

Future<String> sendEventWithTags(Store node, Event e, String tags) async {
  String strTags = tags;
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
  String content = addEscapeChars( e.eventData.content);

  String id = getShaId(userPublicKey, createdAt.toString(), e.eventData.kind.toString(), strTags, content);
  String sig = mySign(userPrivateKey, id);

  String toSendMessage = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":${e.eventData.kind.toString()},"tags":[$strTags],"content":"$content","sig":"$sig"}]';
  //print("in send event: calling sendrequest for string \n $toSendMessage");
  sendRequest(gListRelayUrls1, toSendMessage);

  Future<void> foo() async {
    await Future.delayed(Duration(milliseconds: 500));
    return;
  }
  await foo();
  return id;
}


bool sendDeleteEvent(Store node, String eventIdToDelete) {
  if( node.allChildEventsMap.containsKey(eventIdToDelete)) {
    Tree? tree = node.allChildEventsMap[eventIdToDelete];
    if( tree != null) {
      if( tree.event.eventData.id == eventIdToDelete && tree.event.eventData.pubkey == userPublicKey) {
        // to delte this event
        String replyKind = "5"; // delete event
        String content = "";
        String strTags = '["e","$eventIdToDelete"]';
        strTags += gWhetherToSendClientTag?',["client","nostr_console"]':'';

        int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
        String id = getShaId(userPublicKey, createdAt.toString(), replyKind, strTags, content);

        String sig = mySign(userPrivateKey, id);
        String toSendMessage = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":$replyKind,"tags":[$strTags],"content":"$content","sig":"$sig"}]';
        sendRequest( gListRelayUrls1, toSendMessage);
        print("sent event delete request with id = $id");
        //print(toSendMessage);
      } else {
        print("${gWarningColor}The given id was not found and/or is not a valid id, or is not your event. Not deleted.$gColorEndMarker"); 
      }
    } else {
      print("Event not found. Kindly ensure you have entered a valid event id.");
    }
  };

  return false;
}

void reAdjustAlignment() {
    // align the text again in case the window size has been changed
    if( gAlignment == "center") {
      try {
        var terminalColumns = gDefaultTextWidth;

        if( stdout.hasTerminal )
          terminalColumns = stdout.terminalColumns;

        if(  gTextWidth > terminalColumns) {
          gTextWidth = terminalColumns - 5;
        }          
        gNumLeftMarginSpaces = (terminalColumns - gTextWidth )~/2;
      } on StdoutException catch (e) {
        print("Terminal information not available");
        if( gDebug>0)  print("${e.message}");
        gNumLeftMarginSpaces = 0;
      }
    }

    Store.reCalculateMarkerStr();
}

void printProfile(Store node, String profilePubkey) {
  bool onlyUserPostAndLike (Tree t) => t.treeSelectorUserPostAndLike(profilePubkey);
  node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), onlyUserPostAndLike);

  // get the latest kind 3 event for the user, which lists his 'follows' list
  Event? profileContactEvent = getContactEvent(profilePubkey);

  // if contact list was found, get user's feed, and keep the contact list for later use 
  String authorName = gKindONames[profilePubkey]?.name??"";
  String pronoun = "";
  if( profilePubkey == userPublicKey) {
    printUnderlined("\nYour profile ($authorName):");
    pronoun = "You";
  } else {
    printUnderlined("\nProfile for $authorName");
    pronoun = "They";
  }

  print("\nName        : $authorName ( ${profilePubkey} ).");

  if (profileContactEvent != null ) {
    String about = gKindONames[profilePubkey]?.about??"";
    String picture = gKindONames[profilePubkey]?.picture??"";
    int    dateLastUpdated    = gKindONames[profilePubkey]?.createdAt??0;
    bool   verified = gKindONames[profilePubkey]?.nip05Verified??false;
    String nip05Id  = gKindONames[profilePubkey]?.nip05Id??"";

    print("About       : $about");
    print("Picture     : $picture");
    print("Nip 05      : ${verified?"yes. ${nip05Id}":"no"}");
    print("Last Updated: ${getPrintableDate(dateLastUpdated)}\n");
    

    if( profilePubkey != userPublicKey) {
      if( profileContactEvent.eventData.contactList.any((x) => (x.id == userPublicKey))) {
          print("* They follow you");
      } else {
          print("* They don't follow you");
      }
    }

    // print social distance info. 
    node.printSocialDistance(profileContactEvent, authorName);
    print("");
    
    stdout.write("$pronoun follow ${profileContactEvent.eventData.contactList.length} accounts:  ");
    profileContactEvent.eventData.contactList.forEach((x) => stdout.write("${getAuthorName(x.id)}, "));
    print("\n");
  }

  List<String> followers = node.getFollowers(profilePubkey);

  stdout.write("$pronoun have ${followers.length} followers:  ");
  followers.forEach((x) => stdout.write("${getAuthorName(x)}, "));
  print("");              
  print("");
}

void printMenu(List<String> menuOptions) {

  int longestMenuOption = 0;
  for(int i = 0; i < menuOptions.length;i++) {
    if( longestMenuOption < menuOptions[i].length) {
      longestMenuOption = menuOptions[i].length;
    }
  }

  var terminalColumns = gDefaultTextWidth;

  if( stdout.hasTerminal )
    terminalColumns = stdout.terminalColumns;


  if( longestMenuOption + 5> gMenuWidth )
    gMenuWidth = longestMenuOption + 8;

  if( terminalColumns~/gMenuWidth > 4) {
    terminalColumns = gMenuWidth * 4;
  }

  //print("gMenuWidth = $gMenuWidth");
  int rowLen = 0;
  for(int i = 0; i < menuOptions.length;i++) {
    String str = "${i+1}. ${menuOptions[i]}";
    str = str.padRight(gMenuWidth);
    stdout.write(str);
    rowLen += gMenuWidth;

    if( rowLen + gMenuWidth> terminalColumns ) {
      stdout.write("\n" );
      rowLen = 0;
    }
    
  }
  stdout.write("\n" );
  
}

void printVerifiedAccounts(Store node) {

  List<dynamic> listVerified = []; // num follows, pubkey, name, nip05id

  print("Username                   Num Followers             pubkey                                                                    Nip Id");
  gKindONames.forEach((key, value) {
    String pubkey = key;
    if( value.nip05Verified) {
      //print("${getAuthorName(pubkey).padRight(20)}  ${pubkey}   ${value.nip05Id}");
      List<String> followers = node.getFollowers(pubkey);
      listVerified.add([followers.length, pubkey, getAuthorName(pubkey), value.nip05Id]);
    }
    
  });

  listVerified.sort((a, b) => a[0] > b[0]? -1: (a[0] == b[0]? 0: 1));

  for(var verifiedEntry in listVerified) {
    print("${verifiedEntry[2].padRight(20)}  ${verifiedEntry[0]}  ${verifiedEntry[1]}   ${verifiedEntry[3]}");
  }

  for( var uni in gKindONames.values) {
  }
}

void clearScreen() {
  print("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
}

int showMenu(List<String> menuOptions, String menuName, [String menuInfo = ""]) {

  if(menuInfo.length > 0) {
    print("\n$menuInfo\n");
  }

  while(true) {
    //print("\n$menuName\n${getNumDashes(menuName.length)}");
    printInColor("                                     $menuName", yellowColor);
    print("\n");

    printMenu(menuOptions);
    String nameToDisplay = userPrivateKey.length == 64? 
                              "$gCommentColor${getAuthorName(userPublicKey)}$gColorEndMarker": 
                              "${gWarningColor}You are not signed in$gColorEndMarker but are using public key $userPublicKey";

    stdout.write("Signed in as $nameToDisplay. ");
    stdout.write("Type option number: ");
    String? userOptionInput = stdin.readLineSync();
    String userOption = userOptionInput??"";
    userOption = userOption.trim();
    if( userOption == 'x') {
      userOption = menuOptions.length.toString();
    }
    if( int.tryParse(userOption) != null) {
      try{
        int? valueOption = int.tryParse(userOption);
        if( valueOption != null) {
          if( valueOption >= 1 && valueOption <= menuOptions.length) {
            reAdjustAlignment(); // in case user has changed alignment
            print('You picked: $valueOption');
            return valueOption;
          }
        }
      } on FormatException catch (e) {
        print(e.message);
      } on Exception catch (e) {
        print(e);
      }    
    }
    printWarning("\nInvalid option. Kindly try again. The valid options are from 1 to ${menuOptions.length}");

  }
}

Future<void> otherOptionsMenuUi(Store node) async {
  bool continueOtherMenu = true;
  while(continueOtherMenu) {

    await processAnyIncomingEvents(node); // this takes 300 ms

    int option = showMenu([ 'Show user profile',             // 1
                            'Search by client name',         // 2
                            'Search word(s) or event id',    // 3
                            'Display contact list',          // 4 
                            'Follow new contact',            // 5
                            'Edit your profile',             // 6
                            'Change number of days printed', // 7
                            'Delete event',                  // 8
                            'Application stats',             // 9
                            'Help and About',               // 10
                            'E(x)it to main menu'],          // 11


                          "Other Options Menu");                     // menu name
    switch(option) {
      case 1:
        stdout.write("Type username or first few letters of user's public key( or full public key): ");
        String? $tempUserName = stdin.readLineSync();
        String userName = $tempUserName??"";
        if( userName != "") {
          Set<String> pubkey = getPublicKeyFromName(userName); 
          print("There are ${ pubkey.length} public keys for the given name, which are/is: ");
          pubkey.forEach( (x) => print(" $x : ${getNip05Name(x)} "));
          if( pubkey.length > 1) {
            if( pubkey.length > 1) {
              printWarning("Got multiple users with the same name. Try again, and/or type a more unique name or their full public keys.");
            }
          } else {
            if (pubkey.isEmpty ) {
              printWarning("Could not find the user with that id or username.");
            } 
            else {
              printProfile(node, pubkey.first);
            }
          }
        }
        break;

      case 2:
        stdout.write("Enter nostr client name whose events you want to see: ");
        String? $tempWords = stdin.readLineSync();
        String clientName = $tempWords??"";
        if( clientName != "") {
          bool fromClient (Tree t) => t.treeSelectorClientName(clientName);
          node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), fromClient); // search for last gNumLastDays only
        }
        break;

      case 3: // search word or event id
        stdout.write("Enter word(s) to search: ");
        String? $tempWords = stdin.readLineSync();
        String words = $tempWords??"";
        if( words != "") {
          bool onlyWords (Tree t) => t.treeSelectorHasWords(words.toLowerCase());
          node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), onlyWords); // search for last gNumLastDays only
        } else printWarning("Blank word entered. Try again.");
        break;


      case 4: // display contact list
        String authorName = getAuthorName(userPublicKey);
        List<Contact>? contactList = gKindONames[userPublicKey]?.latestContactEvent?.eventData.contactList;
        if( contactList != null) {
          print("\nHere is the contact list for user $userPublicKey ($authorName), which has ${contactList.length} profiles in it:\n");
          contactList.forEach((Contact contact) => stdout.write("${getAuthorName(contact.id)}, "));
          print("");
        }
        break;

      case 5: // follow new contact
        // in case the program was invoked with --pubkey, then user can't send messages
        if( userPrivateKey == "") {
            printWarning("Since no user private key has been supplied, posts/messages can't be sent. Invoke with --prikey");
            break;
        }

        stdout.write("Enter username or first few letters of user's public key( or full public key): ");
        String? $tempUserName = stdin.readLineSync();
        String userName = $tempUserName??"";
        if( userName != "") {
          Set<String> pubkey = getPublicKeyFromName(userName); 
          print("There are ${ pubkey.length} public keys for the given name, which are/is: ");
          pubkey.forEach( (x) => print(" $x : ${getNip05Name(x)} "));
          if( pubkey.length > 1) {
            if( pubkey.length > 1) {
              printWarning("Got multiple users with the same name. Try again, and type a more unique name or id-prefix");
            }
          } else {
            if (pubkey.isEmpty && userName.length != 64) {
                printWarning("Could not find the user with that id or username. You can try again by providing the full 64 byte long hex public key.");
            } 
            else {
              if( pubkey.isEmpty) {
                printWarning("Could not find the user with that id or username in internal store/list. However, since the given id is 64 bytes long, taking that as hex public key and adding them as contact.");
                pubkey.add(userName);
              }

              String pk = pubkey.first;

              // get this users latest contact list event ( kind 3 event)
              Event? contactEvent = getContactEvent(userPublicKey);
              
              if( contactEvent != null) {
                Event newContactEvent = contactEvent;

                bool alreadyContact = false;
                for(int i = 0; i < newContactEvent.eventData.contactList.length; i++) {
                  if( newContactEvent.eventData.contactList[i].id == pubkey.first) {
                    alreadyContact = true;
                    break;
                  }
                }
                if( !alreadyContact) {
                  print('Sending new contact event');
                  Contact newContact = Contact(pk, defaultServerUrl);
                  newContactEvent.eventData.contactList.add(newContact);
                  getUserEvents(gListRelayUrls1, pk, gLimitPerSubscription, getSecondsDaysAgo(gLimitFollowPosts));
                  sendEvent(node, newContactEvent);
                } else {
                  print("The contact already exists in the contact list. Republishing the old contact list.");
                  getUserEvents(gListRelayUrls1, pk, gLimitPerSubscription, getSecondsDaysAgo(gLimitFollowPosts));
                  sendEvent(node, contactEvent);
                }
              } else {
                  // TODO fix the send event functions by streamlining them
                  print('Sending first contact event');
                  
                  String newId = "", newPubkey = userPublicKey,  newContent = "";
                  int newKind = 3;
                  List<List<String>> newEtags = [];
                  List<String> newPtags = [pk];
                  List<List<String>> newTags = [[]];
                  Set<String> newNewLikes = {};
                  int newCreatedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000; 
                  List<Contact> newContactList = [ Contact(pk, defaultServerUrl) ];

                  EventData newEventData = EventData(newId, newPubkey, newCreatedAt, newKind, newContent, newEtags, newPtags, newContactList, newTags, newNewLikes,);
                  Event newEvent = Event( "EVENT", newId, newEventData,  [], "");
                  getUserEvents(gListRelayUrls1, pk, gLimitPerSubscription, getSecondsDaysAgo(gLimitFollowPosts));
                  sendEvent(node, newEvent);
              }
            }
          }
        }
        break;

      case 6: //edit your profile
        print("Your current name: ${getAuthorName(userPublicKey)}");
        print("Your 'about me': ${gKindONames[userPublicKey]?.about}");
        print("Your current profile picture: ${gKindONames[userPublicKey]?.picture}\n");
        print("Your current NIP 05 id: ${gKindONames[userPublicKey]?.nip05Id}");

        print("Enter new data. Leave blank to use the old value:");
        String userName = getStringFromUser("Enter your new display name: ", getAuthorName(userPublicKey));
        String userAbout = getStringFromUser("Enter new 'about me' for yourself: ", gKindONames[userPublicKey]?.about??"");
        String userPic = getStringFromUser("Enter url to your new display picture: ", gKindONames[userPublicKey]?.picture??"https://placekitten.com/200/200");
        String nip05id = getStringFromUser("Enter your nip 05 id. Leave blank if unknown/none: ", gKindONames[userPublicKey]?.nip05Id??"");

        String content = "{\"name\": \"$userName\", \"about\": \"$userAbout\", \"picture\": \"$userPic\"${ nip05id.length >0 ? ", \"nip05\": \"$nip05id\"":""}}";
        int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;

        EventData eventData = EventData('id', userPublicKey, createdAt, 0, content, [], [], [], [], {}, );
        Event userKind0Event = Event("EVENT", "id", eventData, [], "");
        String userKind0EventId = await sendEvent(node, userKind0Event); // takes 400 ms
        printInColor("Updated your profile.\n", gCommentColor);
        await processAnyIncomingEvents(node, false); // get latest event, this takes 300 ms
        break;

      case 7: // change number of days printed
        stdout.write("Enter number of days for which you want to see posts: ");
        String? $tempNumDays = stdin.readLineSync();
        String newNumDays = $tempNumDays??"";

        try {
          gNumLastDays =  int.parse(newNumDays);
          print("Changed number of days printed to $gNumLastDays");
        } on FormatException catch (e) {
          printWarning("Invalid input. Kindly try again."); 
          if( gDebug > 0) print(" ${e.message}"); 
          continue;
        } on Exception catch (e) {
          printWarning("Invalid input. Kindly try again."); 
          if( gDebug > 0) print(" ${e}"); 
          continue;
        }    
        break;
      case 8:
        stdout.write("Enter event id to delete: ");
        String? $tempEventId = stdin.readLineSync();
        String userInputId = $tempEventId??"";
        Set<String> eventIdToDelete = node.getEventEidFromPrefix(userInputId);

        if( eventIdToDelete.length == 1) {
          String toDeleteId = eventIdToDelete.first;
          print("Going to send a delete event for the following event with id ${toDeleteId}");
          sendDeleteEvent(node, eventIdToDelete.first);
          await processAnyIncomingEvents(node, false); // get latest event, this takes 300 ms
        } else {
          if( eventIdToDelete.length == 0) {
            printWarning("Could not find the given event id. Kindly try again, by entering a 64 byte long hex event id, or by entering a unique prefix for the given event id.");
          } else {
            printWarning("Invalid Event Id(s). Kindly enter a more unique id.");
          }
        }

        break;

      case 9: // application info
        print("\n\n");
        printUnderlined("Application stats");
        print("\n");
        relays.printInfo();
        print("\n");
        printUnderlined("Event and User Info");
        //print("Total number of kind-1 posts:  ${node.count()}");

        print("\nEvent distribution by event kind:\n");
        node.printEventInfo();
        print("\nTotal number of all events:    ${node.allChildEventsMap.length}");
        print("Total number of user profiles: ${gKindONames.length}\n");
        printUnderlined("Logged in user Info");
        if( userPrivateKey.length == 64) {
          print("You are signed in, and your public key is:       $userPublicKey");
        } else {
          print("You are not signed in, and are using public key: $userPublicKey");
        }
        print("Your name as seen in metadata event is:          ${getAuthorName(userPublicKey)}\n");

        printVerifiedAccounts(node);
        break;

      case 10:
        print(helpAndAbout);
        break;

      case 11:
        continueOtherMenu = false;
        break;
  

      default:
        break;
    }
  }
  return;
}

// returns a string entered by the user
String getStringFromUser(String prompt, [String defaultValue=""] ) {
  String str = "";
  
  stdout.write(prompt);
  str = (stdin.readLineSync())??"";

  if( str.length == 0)
    str = defaultValue;
  return str;
}

// sends event creating a new public channel
Future<void> createPublicChannel(Store node) async {
  String channelName = getStringFromUser("Enter channel name: ");
  String channelAbout = getStringFromUser("Enter description for channel: ");
  String channelPic = getStringFromUser("Enter display picture if any: ", "https://placekitten.com/200/200");
  String content = "{\"name\": \"$channelName\", \"about\": \"$channelAbout\", \"picture\": \"$channelPic\"}";
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;

  EventData eventData = EventData('id', userPublicKey, createdAt, 40, content, [], [], [], [], {}, );
  Event channelCreateEvent = Event("EVENT", "id", eventData, [], "");
  String newChannelId = await sendEvent(node, channelCreateEvent); // takes 400 ms
  print("Created new channel with id: $newChannelId");
  await processAnyIncomingEvents(node, false); // get latest event, this takes 300 ms
}

Future<void> channelMenuUI(Store node) async {
  bool continueChatMenu = true;
  
  bool justShowedChannels = false;
  while(continueChatMenu) {

    //await processNotifications(node); // this takes 300 ms
    if( !justShowedChannels) {
      printInColor("                                     Public Channels ", gCommentColor);
      node.printChannelsOverview(node.channels, 20, selectorShowAllRooms);
      justShowedChannels = true;
    }

    String menuInfo = """Public channel howto: To enter a channel, enter first few letters of its name or the channel identifier. 
                      When inside a channel, the first column is the id of the given post. It can be used when you want to reply to a specific post.
                      To reply to a specific post, type '/reply <first few letters of id of post to reply to> <your message>. 
                      When in a channel, press 'x' to exit. """;
    int option = showMenu([ 'Enter a public channel',          // 1
                            'Show all public channels',        // 2
                            'Create channel',                  // 3
                            'E(x)it to main menu'],           // 4
                          "Public Channels Menu", // name of menu
                          menuInfo);
    switch(option) {
      case 1:

        justShowedChannels = false;
        bool showChannelOption = true;
        stdout.write("\nType channel id or name, or their 1st few letters; or type 'x' to go to menu: ");
        String? $tempUserInput = stdin.readLineSync();
        String channelId = $tempUserInput??"";

        if( channelId == "x") {
          showChannelOption = false; 
          clearScreen();
        }
        int pageNum = 1;
        bool firstIteration = true;
        while(showChannelOption) {
          reAdjustAlignment();
          if( firstIteration) {
            clearScreen();
            firstIteration = false;
          }

          String fullChannelId = node.showChannel(node.channels, channelId, pageNum);
          if( fullChannelId == "") {
            //print("Could not find the given channel.");
            showChannelOption = false;
            break;
          }


          stdout.write("\nType message; or type 'x' to exit, or press <enter> to refresh: ");
          $tempUserInput = stdin.readLineSync(encoding: utf8);
          String messageToSend = $tempUserInput??"";

          if( messageToSend != "") {
            if( messageToSend == 'x') {
              showChannelOption = false;
            } else {
              int retval = 0;
              if( (retval = messageToSend.isChannelPageNumber(gMaxChannelPagesDisplayed)) != 0 ) {
                print('is channel page number: $retval');
                pageNum = retval;
              } else {

                // in case the program was invoked with --pubkey, then user can't send messages
                if( userPrivateKey == "") {
                    printWarning("Since no user private key has been supplied, posts/messages can't be sent. Invoke with --prikey \n");
                    
                } else {

                //print("message: |$messageToSend|");
                if( messageToSend.length >= 7 && messageToSend.substring(0, 7).compareTo("/reply ") == 0) {
                  List<String> tokens = messageToSend.split(' ');
                  //print("tokens = $tokens");
                  if( tokens.length >= 3) {
                    String replyTo = tokens[1];
                    Channel? channel = node.getChannelFromId(node.channels, fullChannelId);
                    String actualMessage = messageToSend.substring(7);

                    if( messageToSend.indexOf(tokens[1]) + tokens[1].length < messageToSend.length)
                      actualMessage = messageToSend.substring( messageToSend.indexOf(tokens[1]) + tokens[1].length + 1);

                    if( channel != null) {
                      //print("sending reply |$actualMessage|");
                      await sendChannelReply(node, channel, replyTo, actualMessage, "42");
                      pageNum = 1; // reset it 
                    }
                  }

                } else {
                  // send message to the given room
                  //print("sending message |$messageToSend|");
                  Channel? channel = node.getChannelFromId(node.channels, fullChannelId);
                  if( channel != null) {
                    await sendChannelMessage(node, channel,  messageToSend, "42");
                    pageNum = 1; // reset it 
                  }
                  

                }
                }
              }
            }

          } else {
            print("Refreshing...");
          }
          clearScreen();
          await processAnyIncomingEvents(node, false);

        } // end while showChannelOption
        break;

      case 2:
        clearScreen();
        printInColor("                                 All Public Channels ", gCommentColor);
        node.printChannelsOverview(node.channels, node.channels.length, selectorShowAllRooms);
        justShowedChannels = true;
        break;

      case 3:
        clearScreen();
        print("Creating new channel. Kindly enter info about channel: \n");
        await createPublicChannel(node);
        clearScreen();
        justShowedChannels = false;

        // TODO put user in the newly created channel
        break;

      case 4:
        continueChatMenu = false;
        break;

      default:
        break;
    }
  }
  return;
}

// sends event creating a new public channel
Future<void> createEncryptedChannel(Store node) async {
  String channelName = getStringFromUser("Enter encrypted channel name: ");
  String channelAbout = getStringFromUser("Enter description for the new encrypted channel: ");
  String channelPic = getStringFromUser("Enter display picture if any: ", "https://placekitten.com/200/200");
  String content = "{\"name\": \"$channelName\", \"about\": \"$channelAbout\", \"picture\": \"$channelPic\"}";
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;

  List<String> participants = [userPublicKey];
  String pTags = '';
  for( int i = 0; i < participants.length; i++) {
    if( i > 0) {
      pTags += ",";
    }

    pTags += '["p","${participants[i]}"]';
  }

  EventData eventData = EventData('id', userPublicKey, createdAt, 140, content, [], [], [], [], {}, );
  Event encryptedChannelCreateEvent = Event("EVENT", "id", eventData, [], "");
  String newEncryptedChannelId = await sendEventWithTags(node, encryptedChannelCreateEvent, pTags); // takes 400 ms
  clearScreen();
  print("Created new encrypted channel with id: $newEncryptedChannelId\n");


  String newPriKey = getRandomPrivKey();
  //print("Created and going to use new random privake key: $newPriKey");
  String channelPriKey = newPriKey, channelPubKey = myGetPublicKey(newPriKey);

  // now send password as direct message to yourself and to all the people you tagged
  String messageToSend = "App Encrypted Channels: inviting you to encrypted channel $newEncryptedChannelId encrypted using private public keys $channelPriKey $channelPubKey";
  for( int i = 0; i < participants.length; i++) {
    // send message to all ( including self which is in that list)
    await sendDirectMessage(node, participants[i], messageToSend);
  }

  await processAnyIncomingEvents(node, false); // get latest event, this takes 300 ms
}

// sends event creating a new public channel
Future<void> updateEncryptedChannel(Store node, String channelId, 
                                    String channelName, String channelAbout, String channelPic, String content, String tags, 
                                    Set<String> participants, Set<String> newParticipants) async {

  List<String> keys = getEncryptedChannelKeys(node.directRooms, node.allChildEventsMap, channelId);
  if( keys.length == 2) {
    String channelPriKey = keys[0], channelPubKey = keys[1];

    // now send password as direct message to yourself and to all the people you tagged
    String messageToSend = "App Encrypted Channels: inviting you to encrypted channel $channelId encrypted using private public keys $channelPriKey $channelPubKey";
    
    // send message to all new participants
    newParticipants.forEach((participant) async {
      await sendDirectMessage(node, participant, messageToSend);
    });

    int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
    EventData eventData = EventData('id', userPublicKey, createdAt, 141, content, [], [], [], [], {}, );
    Event encryptedChannelCreateEvent = Event("EVENT", "id", eventData, [], "");
    String newEncryptedChannelId = await sendEventWithTags(node, encryptedChannelCreateEvent, tags); // takes 400 ms

    await processAnyIncomingEvents(node, false); // get latest event, this takes 300 ms
  } else {
    printWarning("Could not find shared-secret keys for the channel. Could not update.");
  }
}


String encryptChannelMessage(Store node, String channelId, String messageToSend) {
  String encryptedMessage = '';

  List<String> keys = getEncryptedChannelKeys(node.directRooms, node.allChildEventsMap, channelId);
  if( keys.length != 2) {
    return '';
  }

  String priKey = keys[0], pubKey = keys[1];
  encryptedMessage = myEncrypt(priKey, "02" + pubKey, messageToSend);

  //print("encrypted message");
  return encryptedMessage;
}

Future<void> addUsersToEncryptedChannel(Store node, String fullChannelId, String messageToSend) async {
    // first check user is creator of channel
    Event? channelEvent = node.allChildEventsMap[fullChannelId]?.event;
    if( channelEvent != null) {
      if( channelEvent.eventData.pubkey == userPublicKey) {

        Channel? channel = node.getChannelFromId(node.encryptedChannels, fullChannelId);
        if( channel != null ) {

          Set<String> newParticipants = {};
          Set<String> participants = channel.participants;
          int numOldUsers = participants.length;

          // now send invite 
          List<String> toAdd = [];
          List<String> newPubKeys = messageToSend.split(' ');
          newPubKeys = newPubKeys.sublist(1);

          for(int i = 0; i < newPubKeys.length; i++) {
            if( newPubKeys[i].length != 64) {
              printWarning("Invalid pubkey. The given pubkey should be 64 byte long.");
              continue;
            }
            toAdd.add(newPubKeys[i]);
            newParticipants.add(newPubKeys[i]);
            participants.add(newPubKeys[i]);
          }
          
          String channelName = node.getChannelNameFromId(node.encryptedChannels, fullChannelId);
          String channelAbout = "";
          String channelPic = "https://placekitten.com/200/200";
          String content = channelEvent.eventData.content;

          String tags = '["e","$fullChannelId"]';
          participants.forEach((participant) { 
            tags += ',["p","${participant}"]';
          });

          int numNewUsers = participants.length;

          if( numNewUsers > numOldUsers) {
            print("sending kind 141 invites to: $participants");
            await updateEncryptedChannel(node, fullChannelId, channelName, channelAbout, channelPic, content, tags, participants, newParticipants);
          } else {
            printWarning("Note: No new users added. ");
          }
        }
      }
    }
}

Future<void> encryptedChannelMenuUI(Store node) async {
 
  bool continueChatMenu = true;
  
  bool justShowedChannels = false;
  while(continueChatMenu) {
    await processAnyIncomingEvents(node, false); // this takes 300 ms

    if( !justShowedChannels) {
      printInColor("                                  Encrypted Channels ", gCommentColor);
      node.printChannelsOverview(node.encryptedChannels, 20, selectorShowAllRooms);
      justShowedChannels = true;
    }

    String menuInfo = """Encrypted Channel howto: You can create a channel, and then enter the channel by entering the first few unique letters of its pubkey or name.
                         In case you have been invited to a new channel, you can enter that channel the same way as above.
                         Once in a room/channel, you can then add new participants by typing '/add <their 64 byte hex public key>' and pressing enter.
                         When inside a channel, type '/reply <first few letters of id of post to reply to> <your message> to reply to a post.
                         When in a channel, press 'x' to exit. """;

    int option = showMenu([ 'Enter an encrypted channel',         // 1
                            'Show all encrypted channels',        // 2
                            'Create encrypted channel',           // 3
                            'E(x)it to main menu'],               // 4
                          "Encrypted Channels Menu",  // name of menu
                          menuInfo); 
    switch(option) {
      case 1:

        justShowedChannels = false;
        bool showChannelOption = true;
        stdout.write("\nType channel id or name, or their 1st few letters; or type 'x' to go to menu: ");
        String? $tempUserInput = stdin.readLineSync();
        String channelId = $tempUserInput??"";

        
        if( channelId == "x") {
          showChannelOption = false; 
        }
        bool firstIteration = true;
        int pageNum = 1;
        while(showChannelOption) {
          reAdjustAlignment();

          if( firstIteration) {
            clearScreen();
            firstIteration = false;
          }

          String fullChannelId = node.showChannel(node.encryptedChannels, channelId, pageNum);
          if( fullChannelId == "") {
            //print("Could not find the given channel.");
            showChannelOption = false;
            break;
          }



          stdout.write("\nType message; or type 'x' to exit, or press <enter> to refresh: ");
          $tempUserInput = stdin.readLineSync(encoding: utf8);
          String messageToSend = $tempUserInput??"";

          if( messageToSend != "") {
            if( messageToSend == 'x') {
              showChannelOption = false;
            } else {
              int retval = 0;
              if( (retval = messageToSend.isChannelPageNumber(gMaxChannelPagesDisplayed) ) != 0) {
                pageNum = retval;
              } else {

                // in case the program was invoked with --pubkey, then user can't send messages
                if( userPrivateKey == "") {
                    printWarning("Since no user private key has been supplied, posts/messages can't be sent. Invoke with --prikey");
                } else {
                  if( messageToSend.startsWith('/add ')) {
                    await addUsersToEncryptedChannel(node, fullChannelId, messageToSend);
                    continue;
                  }

                  if( messageToSend.startsWith('/remove ')) {
                    // TODO finish
                    //continue;
                  }

                  // send message to the given room
                  Channel? channel = node.getChannelFromId(node.encryptedChannels, fullChannelId);
                  if( messageToSend.length >= 7 && messageToSend.substring(0, 7).compareTo("/reply ") == 0) {
                    List<String> tokens = messageToSend.split(' ');
                    if( tokens.length >= 3) {
                      String replyTo = tokens[1];
                      String actualMessage = messageToSend.substring(7);

                      if( messageToSend.indexOf(tokens[1]) + tokens[1].length < messageToSend.length)
                        actualMessage = messageToSend.substring( messageToSend.indexOf(tokens[1]) + tokens[1].length + 1);

                      if( channel != null) {
                        String encryptedMessageToSend = encryptChannelMessage(node, fullChannelId, actualMessage);
                        if( encryptChannelMessage != "") {
                          await sendChannelReply(node, channel, replyTo, encryptedMessageToSend, "142");
                          pageNum = 1; // reset it 
                        }
                      }
                    }
                  } else {
                    if( channel != null) {
                      String encryptedMessageToSend = encryptChannelMessage(node, fullChannelId, messageToSend);
                      if( encryptChannelMessage != "") {
                        await sendChannelMessage(node, channel, encryptedMessageToSend, "142");
                        pageNum = 1; // reset it 
                      }
                    } else {
                      printWarning("\nCould not get send message because could not get channel id.");
                    }
                  }

                }
              }
            }
          } else {
            print("Refreshing...");
          }
          clearScreen();
          await processAnyIncomingEvents(node, false);
        } // end while showChennelOption ( showing each page)
        break;

      case 2:
        clearScreen();
        printInColor("                              All Encrypted Channels ", gCommentColor);
        node.printChannelsOverview(node.encryptedChannels, node.encryptedChannels.length, selectorShowAllRooms);
        justShowedChannels = true;
        break;

      case 3:
        clearScreen();
        print("Creating new encrypted channel. Kindly enter info about channel: \n");
        await createEncryptedChannel(node);
        justShowedChannels = false;
        break;

      case 4:
        continueChatMenu = false;
        break;

      default:
        break;
    }
  }
  return;
}


Future<void> PrivateMenuUI(Store node) async {
  bool continueChatMenu = true;
  while(continueChatMenu) {
    await processAnyIncomingEvents(node, true); // this takes 300 ms

    printInColor("                                Direct Messages", gCommentColor);
    node.printDirectRoomInfo(showAllRooms);

    String menuInfo = """Direct Message howto: To send a Direct Message to someone for the first time, enter their 64 byte hex pubkey.
                      To enter or continue a conversation seen in overview, enter the first few letters of the other person's name or of their pubkey""";
    int option = showMenu([ 
                            'Reply or Send a direct message',
                            'E(x)it to main menu'],          // 3
                          "Direct Message Menu", // name of menu
                          menuInfo); 
    switch(option) {

      case 1:
        // in case the program was invoked with --pubkey, then user can't send messages
        if( userPrivateKey == "") {
            print("Since no private key has been supplied, messages and replies can't be sent. Invoke with --prikey \n");
            break;
        }

        bool showChannelOption = true;
        stdout.write("\nType user public key, or their name, or their 1st few letters; or type 'x' to cancel: ");
        String? $tempUserInput = stdin.readLineSync();
        String directRoomId = $tempUserInput??"";

        if( directRoomId == "x") {
          showChannelOption = false; 
        }
        int pageNum = 1;
        while(showChannelOption) {


          String fullChannelId = node.showDirectRoom(directRoomId, pageNum);
          if( fullChannelId == "") {
            printWarning("Could not find the given direct room.");
            showChannelOption = false;
            break;
          }

          stdout.write("\nType message; or type 'x' to exit, or press <enter> to refresh: ");
          $tempUserInput = stdin.readLineSync(encoding: utf8);
          String messageToSend = $tempUserInput??"";

          if( messageToSend != "") {
            if( messageToSend == 'x') {
              showChannelOption = false;
            } else {
              int retval = 0;
              if( (retval = messageToSend.isChannelPageNumber(gMaxChannelPagesDisplayed)) != 0 ) {
                pageNum = retval;
              } else {
                  // in case the program was invoked with --pubkey, then user can't send messages
                  if( userPrivateKey == "") {
                    printWarning("Since no user private key has been supplied, posts/messages can't be sent. Invoke with --prikey \n");
                  }
                  // send message to the given room
                  await sendDirectMessage(node, fullChannelId, messageToSend);
                  await processAnyIncomingEvents(node, false); // get latest message
                  //print("in privateMenuUI: sent message");
                  pageNum = 1; // reset it 
              }
            }
          } else {
            print("Refreshing...");
          }

          await processAnyIncomingEvents(node, false);

        }
        break;

      case 2:
        continueChatMenu = false;
        break;

      default:
        break;
    }
  }
  return;
}

void showInitialNotifications(Store node) {

  bool hasNotifications (Tree t) => t.treeSelectorNotifications();
  node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), hasNotifications);
  print("\n");

  bool showNotifications (ScrollableMessages room) => room.selectorNotifications();
  int numDirectRoomsPrinted = node.printDirectRoomInfo(showNotifications);
  
  if( numDirectRoomsPrinted > 0)
      print("\n");
}

Future<void> mainMenuUi(Store node) async {
   
    clearScreen();
    //log.info("in main menu");
    //Show only notifications
    showInitialNotifications(node);

    bool mainMenuContinue = true;
    while(mainMenuContinue) {

      await processAnyIncomingEvents(node); // this takes 300 ms

      // the main menu
      int option = showMenu(['Display feed',     // 1 
                             'Post/Reply/Like',  // 2
                             'Public Channels',  // 3
                             'Encrypted Channels',// 4
                             'Private Messages', // 5
                             'Other Options',    // 6
                             'E(x)it Application'],            // 7
                             "Main Menu");
      
      switch(option) {
        case 1:
          node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), selectorShowAllTrees);
          break;

        case 2:
          // in case the program was invoked with --pubkey, then user can't send messages
          if( userPrivateKey == "") {
              printWarning("Since no user private key has been supplied, posts/messages can't be sent. Invoke with --prikey \n");
              break;
          }
          stdout.write("Type comment to post/reply (type '+' to send a like): ");
          String? $contentVar = stdin.readLineSync();
          String content = $contentVar??"";
          if( content == "") {
            break;
          }

          stdout.write("\nType id of event to reply to (leave blank to make a new post; type x to cancel): ");
          String? $replyToVar = stdin.readLineSync();
          String replyToId = $replyToVar??"";
          if( replyToId == "x") {
            print("Cancelling post/reply.");
            break;
          }
          String replyKind = "1";
          if( content == "+") {
            print("Sending a like to given post.");
            replyKind = "7";
          } else if( content == "!") {
            print("Hiding the given post.");
            replyKind = "7";
          }

          await sendReplyPostLike(node, replyToId, replyKind, content);
          break;

        case 3:
          clearScreen();
          await channelMenuUI(node);
          clearScreen();
          break;

        case 4:
          clearScreen();
          await encryptedChannelMenuUI(node);
          clearScreen();
          break;

        case 5:
          clearScreen();
          await PrivateMenuUI(node);
          clearScreen();
          break;

        case 6:
          clearScreen();
          await otherOptionsMenuUi(node);
          clearScreen();
          break;

        case 7:
        default:
          mainMenuContinue = false;
          String authorName = getAuthorName(userPublicKey);
          print("\nFinished Nostr session for user with name and public key: ${authorName} ($userPublicKey)");
          if( gEventsFilename != "") {
            await node.writeEventsToFile(gEventsFilename);
          }
          exit(0);
      } // end menu switch
    } // end while
} // end mainMenuUi()


