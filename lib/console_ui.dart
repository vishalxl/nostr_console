import 'dart:io';
import 'package:bip340/bip340.dart';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for the utf8.encode method


int showMenu(List<String> menuOptions) {
  while(true) {
    //print("in showmenu while");
    for(int i = 0; i < menuOptions.length;i++) {
      print("    ${i+1}. ${menuOptions[i]}");
    }

    stdout.write("Type menu option/number: ");

    //print(">");
    String? userOptionInput = stdin.readLineSync();
    String userOption = userOptionInput??"";
    //print("read option $userOption");
    if( int.tryParse(userOption) != null) {
      int? valueOption = int.tryParse(userOption);
      if( valueOption != null) {
        if( valueOption < 1 || valueOption > menuOptions.length) {
          print("Invalid option. Kindly try again.\n");
          continue;
        } else {

          return valueOption;
        }
      }
    } else {
      print("Invalid option. Kindly try again.\n");
    }
  }
}

String getShaId(String pubkey, int createdAt, String strTags, String content) {
  String buf = '[0,"$pubkey",$createdAt,1,[$strTags],"$content"]';
  var bufInBytes = utf8.encode(buf);
  var value = sha256.convert(bufInBytes);
  String id = value.toString();  
  return id;
}

Future<void> otherMenuUi(Tree node, var contactList) async {
  bool continueOtherMenu = true;
  while(continueOtherMenu) {
    print('\n\nPick an option by typing the corresponding\nnumber and then pressing <enter>:');
    int option = showMenu([ 'Display Contact List',    // 1 
                            'Change number of days printed',
                            'Go back to main menu']);           // 3
    print('You picked: $option');
    switch(option) {
      case 1:
        String authorName = getAuthorName(userPublicKey);
        print("\nHere is the contact list for user $userPublicKey ($authorName), which has ${contactList.length} profiles in it:\n");
        contactList.forEach((x) => stdout.write("${getAuthorName(x)}, "));
        print("");
        break;
      case 2:
          String? $tempNumDays = stdin.readLineSync();
          String newNumDays = $tempNumDays??"";

          try {
            gNumLastDays =  int.parse(newNumDays);
            print("Changed number of days printed to $gNumLastDays");
          } on FormatException catch (e) {
            print(e.message);
            return;
          } on Exception catch (e) {
            print(e);
            return;
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

    // at the very beginning, show the tree as it is the, and them show the options menu
    node.printTree(0, true, DateTime.now().subtract(Duration(days:gNumLastDays)));
    //gDebug = 1;
    bool userContinue = true;
    while(userContinue) {
      // align the text again in case the window size has been changed
      if( gAlignment == "center") {
        gNumLeftMarginSpaces = (stdout.terminalColumns - gTextWidth )~/2;
      }

      // need a bit of wait to give other events to execute, so do a delay, which allows
      // relays to recieve and handle new events
      const int waitMilliSeconds = 400;
      Future.delayed(const Duration(milliseconds: waitMilliSeconds), ()  {
        
        List<String> newEventsId = node.insertEvents(getRecievedEvents());
        node.printNotifications(newEventsId);
        clearEvents();
      });

      Future<void> foo() async {
        await Future.delayed(Duration(milliseconds: waitMilliSeconds + 100));
        return;
      }
      await foo();

      // the main menu
      print('\n\nPick an option by typing the corresponding\nnumber and then pressing <enter>:');
      int option = showMenu(['Display events',    // 1 
                             'Post/Reply',        // 2
                             'Other Options',     //3
                             'Quit']);            // 3
      print('You picked: $option');
      switch(option) {
        case 1:
          node.printTree(0, true, DateTime.now().subtract(Duration(days:gNumLastDays)));
          break;

        case 2:
          // in case the program was invoked with --pubkey, then user can't send messages
          if( userPrivateKey == "") {
              print("Since no user private key has been supplied, messages can't sent. Invoke with --prikey \n");
              break;
          }
          stdout.write("Type comment to post/reply: ");
          String? $contentVar = stdin.readLineSync();
          String content = $contentVar??"";
          if( content == "") {
            break;
          }

          stdout.write("\nType initial few letters of the id of event to\nreply to (leave blank if you want to make a\nnew post; type x if you want to cancel): ");
          String? $replyToVar = stdin.readLineSync();
          String replyToId = $replyToVar??"";
          if( replyToId == "x") {
            print("Cancelling post/reply.");
            break;
          }
          String strTags = node.getTagStr(replyToId, exename);
          int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
          
          String id = getShaId(userPublicKey, createdAt, strTags, content);
          String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");

          String toSendMessage = '["EVENT", {"id": "$id","pubkey": "$userPublicKey","created_at": $createdAt,"kind": 1,"tags": [$strTags],"content": "$content","sig": "$sig"}]';
          relays.sendMessage(toSendMessage, defaultServerUrl);
          break;

        case 3:
          //print("\n\nNot yet implemented.");
          otherMenuUi(node, contactList);
          break;

        case 4:
        default:
          userContinue = false;
          String authorName = getAuthorName(userPublicKey);
          print("\nFinished fetching feed for user $userPublicKey ($authorName), whose contact list has ${contactList.length} profiles.\n ");
          contactList.forEach((x) => stdout.write("${getAuthorName(x)}, "));
          stdout.write("\n");
          exit(0);
      }
    } // end while
}
