import 'dart:io';
import 'dart:convert';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:nostr_console/settings.dart';
import 'package:bip340/bip340.dart';

Future<void> processNotifications(Store node)  async {
  // need a bit of wait to give other events to execute, so do a delay, which allows
  // relays to recieve and handle new events
  const int waitMilliSeconds = 200;
  Future.delayed(const Duration(milliseconds: waitMilliSeconds), ()  {
    
    Set<String> newEventIdsSet = node.processIncomingEvent(getRecievedEvents());
    String nameToDisplay = userPrivateKey.length == 64? 
                              "$gCommentColor${getAuthorName(userPublicKey)}$gColorEndMarker": 
                              "${gWarningColor}You are not signed in$gColorEndMarker but are using public key $userPublicKey";
    node.printNotifications(newEventIdsSet, nameToDisplay);
    clearEvents();
  });

  Future<void> foo() async {
    await Future.delayed(Duration(milliseconds: waitMilliSeconds + 200));
    return;
  }
  await foo();
}

/* @function sendReplyPostLike Used to send Reply, Post and Like ( event 1 for reply and post, and event 7 for like/reaction)
 * If replyToId is blank, then it does not reference any e/p tags, and thus becomes a top post
 * otherwise e and p tags are found for the given event being replied to, if that event data is available
 */
Future<void> sendReplyPostLike(Store node, String replyToId, String replyKind, String content) async {
  String strTags = node.getTagStr(replyToId, exename);
  if( replyToId.isNotEmpty && strTags == "") { // this returns empty only when the given replyto ID is non-empty, but its not found ( nor is it 64 bytes)
    print("${gWarningColor}The given target id was not found and/or is not a valid id. Not sending the event.$gColorEndMarker"); 
    return; 
  }

  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
  String id = getShaId(userPublicKey, createdAt, replyKind, strTags, content);

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
      id = getShaId(userPublicKey, createdAt, replyKind, vanityTag, content);
      if( id.substring(0, numBytes) == zeroString) {
        break;
      }
    }

    if( gDebug > 0) log.info("Ending pow numShaDone = $numShaDone id = $id");
  }

  String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");

  String toSendMessage = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":$replyKind,"tags":[$vanityTag],"content":"$content","sig":"$sig"}]';
  //relays.sendRequest(defaultServerUrl, toSendMessage);
  sendRequest( gListRelayUrls1, toSendMessage);
}

// is same as above. remove it TODO
Future<void> sendChatMessage(Store node, String channelId, String messageToSend) async {
  String replyKind = "42";

  String strTags = node.getTagStr(channelId, exename);
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
  
  String id = getShaId(userPublicKey, createdAt, replyKind, strTags, messageToSend);
  String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");

  String toSendMessage = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":$replyKind,"tags":[$strTags],"content":"$messageToSend","sig":"$sig"}]';
  //relays.sendRequest(defaultServerUrl, toSendMessage);
  
  sendRequest( gListRelayUrls1, toSendMessage);
}

// send DM
Future<void> sendDirectMessage(Store node, String otherPubkey, String messageToSend) async {
  String otherPubkey02 = "02" + otherPubkey;
  String encryptedMessageToSend =        myEncrypt(userPrivateKey, otherPubkey02, messageToSend);

/*  int ivIndex = encryptedMessageToSend.indexOf("?iv=");
  var iv = encryptedMessageToSend.substring( ivIndex + 4, encryptedMessageToSend.length);
  var enc_str = encryptedMessageToSend.substring(0, ivIndex);
  String decrypted = myPrivateDecrypt(userPrivateKey, otherPubkey02, enc_str, iv);
*/

  String replyKind = "4";
  String strTags = '["p","$otherPubkey"]';
  strTags += gWhetherToSendClientTag?',["client","nostr_console"]':'';
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;

  String id = getShaId(userPublicKey, createdAt, replyKind, strTags, encryptedMessageToSend);
  String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");
  String eventStrToSend = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":$replyKind,"tags":[$strTags],"content":"$encryptedMessageToSend","sig":"$sig"}]';
 
  sendRequest( gListRelayUrls1, eventStrToSend);
}

// sends event e; used to send kind 3 event
Future<void> sendEvent(Store node, Event e) async {
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
  }

  // TODO send event for kinds other than 3 ( which can only have p tags)

  String id = getShaId(userPublicKey, createdAt, e.eventData.kind.toString(), strTags, content);
  String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");

  String toSendMessage = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":${e.eventData.kind.toString()},"tags":[$strTags],"content":"$content","sig":"$sig"}]';
  //print("in send event: calling sendrequiest");
  sendRequest(gListRelayUrls1, toSendMessage);
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
        String id = getShaId(userPublicKey, createdAt, replyKind, strTags, content);

        String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");
        String toSendMessage = '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":$replyKind,"tags":[$strTags],"content":"$content","sig":"$sig"}]';
        sendRequest( gListRelayUrls1, toSendMessage);
        print("sent event delete request with id = $id");
        print(toSendMessage);
      } else {
        print("${gWarningColor}The given id was not found and/or is not a valid id, or is not your event. Not deleted.$gColorEndMarker"); 
      }
    } else {
      print("Event not found. Kindly ensure you have entered a valid event id.");
    }
  };

  return false;
}

void readjustAlignment() {
    // align the text again in case the window size has been changed
    if( gAlignment == "center") {
      try {
        if( gTextWidth > stdout.terminalColumns) {
          gTextWidth = stdout.terminalColumns - 5;
        }          
        gNumLeftMarginSpaces = (stdout.terminalColumns - gTextWidth )~/2;
      } on StdoutException catch (e) {
        print("Terminal information not available");
        if( gDebug>0)  print("${e.message}");
        gNumLeftMarginSpaces = 0;
      }
    }
}

int showMenu(List<String> menuOptions, String menuName) {
  print("\n$menuName\n${getNumDashes(menuName.length)}");
  print('Pick an option:');
  while(true) {
    for(int i = 0; i < menuOptions.length;i++) {
      print("    ${i+1}. ${menuOptions[i]}");
    }

    stdout.write("Type menu option/number: ");
    String? userOptionInput = stdin.readLineSync();
    String userOption = userOptionInput??"";
    if( int.tryParse(userOption) != null) {
      try{
        int? valueOption = int.tryParse(userOption);
        if( valueOption != null) {
          if( valueOption >= 1 && valueOption <= menuOptions.length) {
            readjustAlignment(); // in case user has changed alignment
            return valueOption;
          }
        }
      } on FormatException catch (e) {
        print(e.message);
      } on Exception catch (e) {
        print(e);
      }    
    }
    print("\nInvalid option. Kindly try again. The valid options are from 1 to ${menuOptions.length}\n");

  }
}

Future<void> otherMenuUi(Store node) async {
  //gDebug = 1;
  bool continueOtherMenu = true;
  while(continueOtherMenu) {
    int option = showMenu([ 'Show user profile',             // 1
                            'Search by client name',         // 2
                            'Search word(s) or event id',    // 3
                            'Display contact list',          // 4 
                            'Follow new contact',            // 5
                            'Change number of days printed', // 6
                            'Delete event',                  // 7
                            'Application stats',             // 8
                            'Go back to main menu',          // 9
                            'Help and About'],               // 10

                          "Other Menu");                     // menu name
    print('You picked: $option');
    switch(option) {
      case 1:
        stdout.write("Type username or first few letters of user's public key( or full public key): ");
        String? $tempUserName = stdin.readLineSync();
        String userName = $tempUserName??"";
        if( userName != "") {
          Set<String> pubkey = getPublicKeyFromName(userName); 
          print("There are ${ pubkey.length} public keys for the given name, which are/is: ");
          pubkey.forEach( (x) => print(" $x"));
          if( pubkey.length > 1) {
            if( pubkey.length > 1) {
              print("Got multiple users with the same name. Try again, and try to type a more unique name or id-prefix");
            }
          } else {
            if (pubkey.isEmpty ) {
              print("Could not find the user with that id or username.");
            } 
            else {
              String pk = pubkey.first;
              bool onlyUserPostAndLike (Tree t) => t.hasUserPostAndLike(pk);
              node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), onlyUserPostAndLike);
              
              // get the latest kind 3 event for the user, which lists his 'follows' list
              Event? contactEvent = getContactEvent(pubkey.first);

              // if contact list was found, get user's feed, and keep the contact list for later use 
              String authorName = gKindONames[pubkey.first]?.name??"";
              printUnderlined("\nProfile for User");
              print("\nName        : $authorName ( ${pubkey.first} ).");

              if (contactEvent != null ) {
                String about = gKindONames[pubkey.first]?.about??"";
                String picture = gKindONames[pubkey.first]?.picture??"";
                int    dateLastUpdated    = gKindONames[pubkey.first]?.createdAt??0;

                print("About       : $about");
                print("Picture     : $picture");
                print("Last Updated: ${getPrintableDate(dateLastUpdated)}"); 

                if( contactEvent.eventData.contactList.any((x) => (x.id == userPublicKey))) {
                    print("\n* They follow you");
                } else {
                    print("\n* They don't follow you");
                }

                // print social distance info. 
                node.printSocialDistance(pubkey.first, authorName);
                print("");
                
                stdout.write("They follow ${contactEvent.eventData.contactList.length} accounts:  ");
                contactEvent.eventData.contactList.forEach((x) => stdout.write("${getAuthorName(x.id)}, "));
                print("\n");
              }

              List<String> followers = node.getFollowers(pubkey.first);
              stdout.write("They have ${followers.length} followers:  ");
              followers.forEach((x) => stdout.write("${getAuthorName(x)}, "));
              print("");              
              print("");
            }
          }
        }
        break;

      case 2:
        stdout.write("Enter nostr client name whose events you want to see: ");
        String? $tempWords = stdin.readLineSync();
        String clientName = $tempWords??"";
        if( clientName != "") {
          bool fromClient (Tree t) => t.fromClientSelector(clientName);
          node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), fromClient); // search for last gNumLastDays only
        }
        break;

      case 3: // search word or event id
        stdout.write("Enter word(s) to search: ");
        String? $tempWords = stdin.readLineSync();
        String words = $tempWords??"";
        if( words != "") {
          bool onlyWords (Tree t) => t.hasWords(words.toLowerCase());
          node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), onlyWords); // search for last gNumLastDays only
        } else print("Blank word entered. Try again.");
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
            print("Since no user private key has been supplied, posts/messages can't be sent. Invoke with --prikey \n");
            break;
        }

        stdout.write("Enter username or first few letters of user's public key( or full public key): ");
        String? $tempUserName = stdin.readLineSync();
        String userName = $tempUserName??"";
        if( userName != "") {
          Set<String> pubkey = getPublicKeyFromName(userName); 
          print("There are ${ pubkey.length} public keys for the given name, which are/is: ");
          print(pubkey);
          if( pubkey.length > 1) {
            if( pubkey.length > 1) {
              print("Got multiple users with the same name. Try again, and type a more unique name or id-prefix");
            }
          } else {
            if (pubkey.isEmpty && userName.length != 64) {
                print("Could not find the user with that id or username. You can try again by providing the full 64 byte long hex public key.");
            } 
            else {
              if( pubkey.isEmpty) {
                print("Could not find the user with that id or username in internal store/list. However, since the given id is 64 bytes long, taking that as hex public key and adding them as contact.");
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
                  sendEvent(node, newContactEvent);
                } else {
                  print("The contact already exists in the contact list. Republishing the old contact list.");
                  sendEvent(node, contactEvent);
                  getUserEvents(gListRelayUrls1, pk, gLimitPerSubscription, getSecondsDaysAgo(gDaysToGetEventsFor));
                }
              } else {
                  // TODO fix the send event functions by streamlining them
                  print('Sending first contact event');
                  
                  String newId = "", newPubkey = userPublicKey,  newContent = "";
                  int newKind = 3;
                  List<String> newEtags = [], newPtags = [pk];
                  List<List<String>> newTags = [[]];
                  Set<String> newNewLikes = {};
                  int newCreatedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000; 
                  List<Contact> newContactList = [ Contact(pk, defaultServerUrl) ];

                  EventData newEventData = EventData(newId, newPubkey, newCreatedAt, newKind, newContent, newEtags, newPtags, newContactList, newTags, newNewLikes,);
                  Event newEvent = Event( "EVENT", newId, newEventData,  [], "");
                  sendEvent(node, newEvent);
                  getUserEvents(gListRelayUrls1, pk, gLimitPerSubscription, getSecondsDaysAgo(gDaysToGetEventsFor));
              }
            }
          }
        }
        break;

      case 6: // change number of days printed
        stdout.write("Enter number of days for which you want to see posts: ");
        String? $tempNumDays = stdin.readLineSync();
        String newNumDays = $tempNumDays??"";

        try {
          gNumLastDays =  int.parse(newNumDays);
          print("Changed number of days printed to $gNumLastDays");
        } on FormatException catch (e) {
          print("Invalid input. Kindly try again."); 
          if( gDebug > 0) print(" ${e.message}"); 
          continue;
        } on Exception catch (e) {
          print("Invalid input. Kindly try again."); 
          if( gDebug > 0) print(" ${e}"); 
          continue;
        }    
        break;
      case 7:
        stdout.write("Enter event id to delete: ");
        String? $tempEventId = stdin.readLineSync();
        String userInputId = $tempEventId??"";
        Set<String> eventIdToDelete = node.getEventEidFromPrefix(userInputId);

        if( eventIdToDelete.length == 1) {
          String toDeleteId = eventIdToDelete.first;
          print("Going to send a delete event for the following event with id ${toDeleteId}");
          sendDeleteEvent(node, eventIdToDelete.first);
        } else {
          print("Invalid Event Id(s) entered = {$eventIdToDelete}");
        }

        break;

      case 8: // application info
        print("\n\n");
        printUnderlined("Application stats");
        print("\n");
        relays.printInfo();
        print("\n");
        printUnderlined("Posts");
        print("Total number of posts: ${node.count()}\n");
        printUnderlined("User Info");
        if( userPrivateKey.length == 64) {
          print("You are signed in, and your public key is:       $userPublicKey");
        } else {
          print("You are not signed in, and are using public key: $userPublicKey");
        }
        print("Your name as seen in metadata event is:          ${getAuthorName(userPublicKey)}");        
        break;

      case 9:
        continueOtherMenu = false;
        break;

      case 10:
        print(helpAndAbout);
        break;
  

      default:
        break;
    }
  }
  return;
}

Future<void> channelMenuUI(Store node) async {
  bool continueChatMenu = true;
  while(continueChatMenu) {
    int option = showMenu([ 'Show public channels',          // 1 
                            'Enter a public channel',        // 2
                            'Go back to main menu'],         // 3
                          "Public Channels Menu"); // name of menu
    print('You picked: $option');
    switch(option) {
      case 1:
        node.printAllChannelsInfo();
        break;
      case 2:

        bool showChannelOption = true;
        stdout.write("\nType channel id or name, or their 1st few letters; or type 'x' to go to menu: ");
        String? $tempUserInput = stdin.readLineSync();
        String channelId = $tempUserInput??"";

        if( channelId == "x") {
          showChannelOption = false; 
        }
        int pageNum = 1;
        while(showChannelOption) {
          readjustAlignment();
          String fullChannelId = node.showChannel(channelId, pageNum);
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
              if( messageToSend.isChannelPageNumber(gMaxChannelPagesDisplayed) ) {
                pageNum = (int.tryParse(messageToSend))??1;
              } else {

                // in case the program was invoked with --pubkey, then user can't send messages
                if( userPrivateKey == "") {
                    print("Since no user private key has been supplied, posts/messages can't be sent. Invoke with --prikey \n");
                    
                } else {
                  // send message to the given room
                  await sendChatMessage(node, fullChannelId, messageToSend);
                  pageNum = 1; // reset it 
                }
              }
            }
          } else {
            print("Refreshing...");
          }

          await processNotifications(node);
        }
        break;

      case 3:
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
    int option = showMenu([ 'See personal Inbox',
                            'Reply or Send a direct message',
                            'Go back to main menu'],          // 3
                          "Private Message Menu"); // name of menu
    print('You picked: $option');
    switch(option) {
      case 1:
        //print("total direct rooms = ${node.directRooms.length}");
        node.printDirectRoomInfo();
        break;
      
      case 2:
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
            print("Could not find the given direct room.");
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
              if( messageToSend.isChannelPageNumber(gMaxChannelPagesDisplayed) ) {
                pageNum = (int.tryParse(messageToSend))??1;
              } else {
                  // in case the program was invoked with --pubkey, then user can't send messages
                  if( userPrivateKey == "") {
                    print("Since no user private key has been supplied, posts/messages can't be sent. Invoke with --prikey \n");
                  }
                  // send message to the given room
                  await sendDirectMessage(node, fullChannelId, messageToSend);
                  print("in privateMenuUI: sent message");
                  pageNum = 1; // reset it 
              }
            }
          } else {
            print("Refreshing...");
          }
          await processNotifications(node);
        }
        break;

      case 3:
        continueChatMenu = false;
        break;

      default:
        break;
    }
  }
  return;
}

Future<void> mainMenuUi(Store node) async {
    // at the very beginning, show the tree with re reply and likes, and then show the options menu
    // bool hasRepliesAndLikes (Tree t) => t.hasRepliesAndLikes(userPublicKey);
    node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), selectAll);
    
    bool userContinue = true;
    while(userContinue) {

      await processNotifications(node); // this takes 300 ms

      // the main menu
      int option = showMenu(['Display feed',     // 1 
                             'Post/Reply/Like',  // 2
                             'Public Channels',  // 3
                             'Private Messages', // 4
                             'Other Options',    // 5
                             'Quit'],            // 6
                             "Main Menu");
      print('You picked: $option');
      switch(option) {
        case 1:
          node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), selectAll);
          break;

        case 2:
          // in case the program was invoked with --pubkey, then user can't send messages
          if( userPrivateKey == "") {
              print("Since no user private key has been supplied, posts/messages can't be sent. Invoke with --prikey \n");
              break;
          }
          stdout.write("Type comment to post/reply (type '+' to send a like): ");
          String? $contentVar = stdin.readLineSync();
          String content = $contentVar??"";
          if( content == "") {
            break;
          }

          content = addEscapeChars(content);
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
          await channelMenuUI(node);
          break;

        case 4:
          await PrivateMenuUI(node);
          break;

        case 5:
          await otherMenuUi(node);
          break;

        case 6:
        default:
          userContinue = false;
          String authorName = getAuthorName(userPublicKey);
          print("\nFinished Nostr session for user with name and public key: ${authorName} ($userPublicKey)");
          if( gEventsFilename != "") {
            await node.writeEventsToFile(gEventsFilename);
          }
          exit(0);
      } // end menu switch
    } // end while
} // end mainMenuUi()
