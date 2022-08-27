import 'dart:io';
import 'dart:convert';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:nostr_console/settings.dart';
import 'package:bip340/bip340.dart';

Future<void> processNotifications(Tree node)  async {
  // need a bit of wait to give other events to execute, so do a delay, which allows
  // relays to recieve and handle new events
  const int waitMilliSeconds = 400;
  Future.delayed(const Duration(milliseconds: waitMilliSeconds), ()  {
    
    List<String> newEventsId = node.insertEvents(getRecievedEvents());
    String nameToDisplay = userPrivateKey.length == 64? 
                              "$gCommentColor${getAuthorName(userPublicKey)}$colorEndMarker": 
                              "${gWarningColor}You are not signed in$colorEndMarker but are using public key $userPublicKey";
    node.printNotifications(newEventsId, nameToDisplay);
    clearEvents();
  });

  Future<void> foo() async {
    await Future.delayed(Duration(milliseconds: waitMilliSeconds + 100));
    return;
  }
  await foo();
}

/* @function sendReplyPostLike Used to send Reply, Post and Like ( event 1 for reply and post, and event 7 for like/reaction)
 * If replyToId is blank, then it does not reference any e/p tags, and thus becomes a top post
 * otherwise e and p tags are found for the given event being replied to, if that event data is available
 */
Future<void> sendReplyPostLike(Tree node, String replyToId, String replyKind, String content) async {
  String strTags = node.getTagStr(replyToId, exename);
  if( replyToId.isNotEmpty && strTags == "") { // this returns empty only when the given replyto ID is non-empty, but its not found ( nor is it 64 bytes)
    print("${gWarningColor}The given target id was not found and/or is not a valid id. Not sending the event.$colorEndMarker"); 
    return; 
  }

  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
  String id = getShaId(userPublicKey, createdAt, replyKind, strTags, content);
  String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");

  String toSendMessage = '["EVENT", {"id": "$id","pubkey": "$userPublicKey","created_at": $createdAt,"kind": $replyKind,"tags": [$strTags],"content": "$content","sig": "$sig"}]';
  relays.sendRequest(defaultServerUrl, toSendMessage);
}

Future<void> sendChatMessage(Tree node, String channelId, String messageToSend) async {
  String replyKind = "42";

  String strTags = node.getTagStr(channelId, exename);
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
  
  String id = getShaId(userPublicKey, createdAt, replyKind, strTags, messageToSend);
  String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");

  String toSendMessage = '["EVENT", {"id": "$id","pubkey": "$userPublicKey","created_at": $createdAt,"kind": $replyKind,"tags": [$strTags],"content": "$messageToSend","sig": "$sig"}]';
  relays.sendRequest(defaultServerUrl, toSendMessage);
}

Future<void> sendEvent(Tree node, Event e) async {
  String strTags = "";
  int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
  String content = addEscapeChars( e.eventData.content);

  if( e.eventData.kind == 3) {
    strTags = ""; // only new contacts will be sent
    for(int i = 0; i < e.eventData.contactList.length; i++) {
      String relay = e.eventData.contactList[i].relay;
      if( relay == "") {
        relay = defaultServerUrl;
      }
      String strContact = '["p","${e.eventData.contactList[i].id}"],';
      strTags += strContact;
    }
    strTags += '["client","nostr_console"]';
  }

  String id = getShaId(userPublicKey, createdAt, e.eventData.kind.toString(), strTags, content);
  String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");

  String toSendMessage = '["EVENT", {"id":"$id","pubkey":"$userPublicKey","created_at":$createdAt,"kind":${e.eventData.kind.toString()},"tags":[$strTags],"content":"$content","sig":"$sig"}]';
  //print("in send event: calling sendrequiest");
  relays.sendRequest(defaultServerUrl, toSendMessage);
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

Future<void> otherMenuUi(Tree node, var contactList) async {
  //gDebug = 1;
  bool continueOtherMenu = true;
  while(continueOtherMenu) {
    int option = showMenu([ 'Show user profile',             // 1
                            'Display contact list',          // 2 
                            'Follow new contact',            // 3
                            'Search word(s)',                // 4
                            'Search by client name',         // 5
                            'Change number of days printed', // 6
                            'Applicatoin stats',             // 7
                            'Help and About',                // 8
                            'Go back to main menu'],         // 9
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
              Event? contactEvent = node.getContactEvent(pubkey.first);

              // if contact list was found, get user's feed, and keep the contact list for later use 
              String authorName = gKindONames[pubkey.first]?.name??"";
              List<String> contactList = [];
              printUnderlined("\nProfile for User");
              print("\nName   : $authorName ( ${pubkey.first} ).");

              if (contactEvent != null ) {
                String about = gKindONames[pubkey.first]?.about??"";
                String picture = gKindONames[pubkey.first]?.picture??"";

                print("About  : $about");
                print("Picture: $picture");

                if( contactEvent.eventData.contactList.any((x) => (x.id == userPublicKey))) {
                    print("\n* They follow you");
                } else {
                    print("\n* They don't follow you");
                }

                // print social distance info. 
                node.printSocialDistance(pubkey.first, authorName);
                print("\n");
                
                stdout.write("They follows ${contactEvent.eventData.contactList.length} accounts:  ");
                contactEvent.eventData.contactList.forEach((x) => stdout.write("${getAuthorName(x.id)}, "));
                print("\n\n");

                List<String> followers = node.getFollowers(pubkey.first);
                stdout.write("They have ${followers.length} followers:  ");
                followers.forEach((x) => stdout.write("${getAuthorName(x)}, "));
                print("");

              }
              print("");
            }
          }
        }
        break;

      case 2:
        String authorName = getAuthorName(userPublicKey);
        print("\nHere is the contact list for user $userPublicKey ($authorName), which has ${contactList.length} profiles in it:\n");
        contactList.forEach((x) => stdout.write("${getAuthorName(x)}, "));
        print("");
        break;

      case 3:
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
              Event? contactEvent = node.getContactEvent(userPublicKey);
              
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
                }

              }

              //print("TBD");
            }
          }
        }
        break;

      case 4:
        stdout.write("Enter word(s) to search: ");
        String? $tempWords = stdin.readLineSync();
        String words = $tempWords??"";
        if( words != "") {
          bool onlyWords (Tree t) => t.hasWords(words.toLowerCase());
          node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), onlyWords); // search for last gNumLastDays only
        }
        break;

      case 5:
        stdout.write("Enter nostr client name whose events you want to see: ");
        String? $tempWords = stdin.readLineSync();
        String clientName = $tempWords??"";
        if( clientName != "") {
          bool fromClient (Tree t) => t.fromClientSelector(clientName);
          node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), fromClient); // search for last gNumLastDays only
        }
        break;

      case 6:
        stdout.write("Enter number of days for which you want to see posts: ");
        String? $tempNumDays = stdin.readLineSync();
        String newNumDays = $tempNumDays??"";

        try {
          gNumLastDays =  int.parse(newNumDays);
          print("Changed number of days printed to $gNumLastDays");
        } on FormatException catch (e) {
          print("Invalid input. Kindly try again.");
          continue;
        } on Exception catch (e) {
          print("Invalid input. Kindly try again.");
          continue;
        }    

        break;


      case 7:

        print("\n\n");
        printUnderlined("Application stats");
        print("\n");
        relays.printInfo();
        print("\n");
        printUnderlined("Posts");
        print("Total number of posts: ${node.count()}");
        print("\n");
        printUnderlined("User Info");
        if( userPrivateKey.length == 64) {
          print("You are signed in, and your public key is:       $userPublicKey");
        } else {
          print("You are not signed in, and are using public key: $userPublicKey");
        }
        print("Your name as seen in metadata event is:          ${getAuthorName(userPublicKey)}");
        break;

      case 8:
        print(helpAndAbout);
        break;
  
      case 9:
        continueOtherMenu = false;
        break;

      default:
        break;
    }
  }
  return;
}

Future<void> channelMenuUI(Tree node, var contactList) async {
  //gDebug = 0;
  bool continueChatMenu = true;
  while(continueChatMenu) {
    int option = showMenu([ 'Show channels',          // 1 
                            'Enter a channel',          // 2
                            'Go back to main menu'],  // 3
                          "Channel Menu"); // name of menu
    print('You picked: $option');
    switch(option) {
      case 1:
        node.printAllChannelsInfo();
        break;
      case 2:
        // in case the program was invoked with --pubkey, then user can't send messages
        if( userPrivateKey == "") {
            print("Since no user private key has been supplied, posts/messages can't be sent. Invoke with --prikey \n");
            break;
        }

        bool showChannelOption = true;
        stdout.write("\nType unique channel id or name, or their 1st few letters; or type 'x' to go back to exit channel: ");
        String? $tempUserInput = stdin.readLineSync();
        String channelId = $tempUserInput??"";

        if( channelId == "x") {
          showChannelOption = false; 
        }
        while(showChannelOption) {
          String fullChannelId = node.showChannel(channelId);
          if( fullChannelId == "") {
            print("Could not find the given channel.");
            showChannelOption = false;
            break;
          }

          stdout.write("\nType message to send to this room; or type 'x' to exit the channel, or just press <enter> to refresh: ");
          $tempUserInput = stdin.readLineSync(encoding: utf8);
          String messageToSend = $tempUserInput??"";

          if( messageToSend != "") {
            if( messageToSend == 'x') {
              showChannelOption = false;
            } else {
              // send message to the given room
              await sendChatMessage(node, fullChannelId, messageToSend);
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

Future<void> mainMenuUi(Tree node, var contactList) async {
    //gDebug = 0;
    // at the very beginning, show the tree as it is, and then show the options menu

    //bool repliesAndLikes (Tree t) => t.repliesAndLikes(userPublicKey);
    node.printTree(0, DateTime.now().subtract(Duration(days:gNumLastDays)), selectAll);

    bool userContinue = true;
    while(userContinue) {
      // align the text again in case the window size has been changed
      if( gAlignment == "center") {
        try {
          if( gTextWidth > stdout.terminalColumns) {
            gTextWidth = stdout.terminalColumns - 5;
          }          
          gNumLeftMarginSpaces = (stdout.terminalColumns - gTextWidth )~/2;
        } on StdoutException catch (e) {
          gNumLeftMarginSpaces = 0;
        }
      }

      await processNotifications(node);
      // the main menu
      int option = showMenu(['Display feed',     // 1 
                             'Post/Reply/Like',  // 2
                             'Channels',          // 3
                             'Other Options',     // 4
                             'Quit'],             // 5
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
          }

          await sendReplyPostLike(node, replyToId, replyKind, content);
          break;

        case 3:
          await channelMenuUI(node, contactList);
          break;

        case 4:
          await otherMenuUi(node, contactList);
          break;

        case 5:
        default:
          userContinue = false;
          String authorName = getAuthorName(userPublicKey);
          print("\nFinished fetching feed for user $userPublicKey ($authorName), whose contact list has ${contactList.length} profiles.\n ");
          contactList.forEach((x) => stdout.write("${getAuthorName(x)}, "));
          stdout.write("\n");
          if( gEventsFilename != "") {
            await node.writeEventsToFile(gEventsFilename);
          }
          exit(0);
      }
    } // end while
}
