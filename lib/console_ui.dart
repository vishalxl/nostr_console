import 'dart:io';
import 'package:bip340/bip340.dart';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for the utf8.encode method

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

String getShaId(String pubkey, int createdAt, String kind, String strTags, String content) {
  String buf = '[0,"$pubkey",$createdAt,$kind,[$strTags],"$content"]';
  if( gDebug > 0) print("In getShaId: for buf = $buf");
  var bufInBytes = utf8.encode(buf);
  var value = sha256.convert(bufInBytes);
  String id = value.toString();  
  return id;
}

Future<void> otherMenuUi(Tree node, var contactList) async {
  bool continueOtherMenu = true;
  while(continueOtherMenu) {
    int option = showMenu([ 'Display Contact List',          // 1 
                            'Change number of days printed', // 2
                            'Go back to main menu'],         // 3
                            "Other Menu");
    print('You picked: $option');
    switch(option) {
      case 1:
        String authorName = getAuthorName(userPublicKey);
        print("\nHere is the contact list for user $userPublicKey ($authorName), which has ${contactList.length} profiles in it:\n");
        contactList.forEach((x) => stdout.write("${getAuthorName(x)}, "));
        print("");
        break;
      case 2:
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

      case 3:
        continueOtherMenu = false;
        break;

      default:
        break;
    }
  }
  return;
}

Future<void> mainMenuUi(Tree node, var contactList) async {
    gDebug = 0;
    // at the very beginning, show the tree as it is the, and them show the options menu
    node.printTree(0, true, DateTime.now().subtract(Duration(days:gNumLastDays)));
    //gDebug = 1;
    bool userContinue = true;
    while(userContinue) {
      // align the text again in case the window size has been changed
      if( gAlignment == "center") {
        try {
          gNumLeftMarginSpaces = (stdout.terminalColumns - gTextWidth )~/2;
        } on StdoutException catch (e) {
          gNumLeftMarginSpaces = 0;
        }
      }

      // need a bit of wait to give other events to execute, so do a delay, which allows
      // relays to recieve and handle new events
      const int waitMilliSeconds = 400;
      Future.delayed(const Duration(milliseconds: waitMilliSeconds), ()  {
        
        List<String> newEventsId = node.insertEvents(getRecievedEvents());
        node.printNotifications(newEventsId, getAuthorName(userPublicKey));
        clearEvents();
      });

      Future<void> foo() async {
        await Future.delayed(Duration(milliseconds: waitMilliSeconds + 100));
        return;
      }
      await foo();

      // the main menu
      int option = showMenu(['Display events',    // 1 
                             'Post/Reply',        // 2
                             'Other Options',     // 3
                             'Quit'],             // 4
                             "Main Menu");
      print('You picked: $option');
      switch(option) {
        case 1:
          node.printTree(0, true, DateTime.now().subtract(Duration(days:gNumLastDays)));
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
          String strTags = node.getTagStr(replyToId, exename);
          int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
          
          String id = getShaId(userPublicKey, createdAt, replyKind, strTags, content);
          String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");

          String toSendMessage = '["EVENT", {"id": "$id","pubkey": "$userPublicKey","created_at": $createdAt,"kind": $replyKind,"tags": [$strTags],"content": "$content","sig": "$sig"}]';
          relays.sendMessage(toSendMessage, defaultServerUrl);
          break;

        case 3:
          otherMenuUi(node, contactList);
          break;

        case 4:
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
