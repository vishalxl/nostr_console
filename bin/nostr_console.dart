import 'dart:io';
import 'package:bip340/bip340.dart';
import 'package:nostr_console/nostr_console_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for the utf8.encode method

var    userPublickey = "3235036bd0957dfb27ccda02d452d7c763be40c91a1ac082ba6983b25238388c";   // vishalxl
//var    userPublickey = "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245"; // jb55
//var    userPublickey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"; // fiatjaf
//var    userPublickey = "ed1d0e1f743a7d19aa2dfb0162df73bacdbc699f67cc55bb91a98c35f7deac69"; // melvin
//var    userPublickey = "52b4a076bcbbbdc3a1aefa3735816cf74993b1b8db202b01c883c58be7fad8bd"; // semisol

// program arguments
const String requestArg  = "request";
const String userArg     = "user";
const String lastdaysArg = "days";
const String relayArg    = "relay";

// By default the threads that were started in last one day are shown
// this can be changed with 'days' command line argument
int numLastDays = 1; 

// well known disposable test private key
const String testPrivateKey = "9d00d99c8dfad84534d3b395280ca3b3e81be5361d69dc0abf8e0fdf5a9d52f9";
const String testPublicKey  = "e8caa2028a7090ffa85f1afee67451b309ba2f9dee655ec8f7e0a02c29388180";

int showMenu(List<String> menuOptions) {
  while(true) {
    print("in showmenu while");
    for(int i = 0; i < menuOptions.length;i++) {
      print("    ${i+1}. ${menuOptions[i]}");
    }

    //print(">");
    String? userOptionInput = stdin.readLineSync();
    String userOption = userOptionInput??"";
    //print("read option $userOption");
    if( !int.parse(userOption).isNaN) {
      int valueOption = int.parse(userOption);
      if( valueOption < 1 || valueOption > menuOptions.length) {
        continue;
      } else {

        return valueOption;
      }
    } else {
      print("Invalid option. Kindly try again.\n");
    }
  }
}

String getShaId(String pubkey, int createdAt, String content) {
  String buf = '[0,"$pubkey",$createdAt,1,[],"$content"]';
  var bufInBytes = utf8.encode(buf);
  var value = sha256.convert(bufInBytes);
  String id = value.toString();  
  return id;
}

Future<void> terminalMenuUi(Tree node, var contactList) async {
    //gDebug = 1;

    bool userContinue = true;
    while(userContinue) {
      //relays.printStatus();

      print('\n\nPick an option by typing the correspoinding\nnumber and then pressing <enter>:');
      int option = showMenu(['Display events',    // 1 
                             'Get Latest events', // 2
                             'Post/Reply',        // 3 
                             'Exit']);            // 4

      
      print('You picked: $option');


      switch(option) {
        case 1:
          //print("in display events option");
          node.printTree(0, true, DateTime.now().subtract(Duration(days:numLastDays)));
          break;

        case 2:
          const int n = 4;
          print("Going to get latest events...");
          //relays.clearHistory();
          //getUserEvents(defaultServerUrl, userPublickey, events, 3000, latestReceivedSeconds);
          Future.delayed(const Duration(seconds: n), ()  {
            print("Number of new events = ${getRecievedEvents().length}");
          });


          Future<void> foo() async {
            //print('foo started');
            await Future.delayed(Duration(seconds: n+1));
            //print('foo executed');
            return;
          }

          await foo();
          node.insertEvents(getRecievedEvents());
          clearEvents();

          break;

        case 3:
          print("Type comment to post/reply: ");
          String? $contentVar = stdin.readLineSync();
          String content = $contentVar??"";
          if( content == "") {
            break;
          }

          int createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
          String id = getShaId(testPublicKey, createdAt, content);
          String sig = sign(testPrivateKey, id, "12345612345612345612345612345612");
          //print("sig = $sig");
          //{"id": "da2a1321c9d2c8d53aa962f1ce83bbeaf00be0bf38e359a858ef269c17490e60","pubkey": "e8caa2028a7090ffa85f1afee67451b309ba2f9dee655ec8f7e0a02c29388180",
          //"created_at": 1660244881,"kind": 1,"tags": [],"content": "test12","sig": "8d36571b0dacdadca1e9b3373c16050a0dc6abf25ec5e6cf9a9075f4877e2a8ca8012e9fcd168a7ff1a631386979282c87b139dec912def9f5764bc7f8cfc7cb"}
          String finalMessage = '["EVENT", {"id": "$id","pubkey": "$testPublicKey","created_at": $createdAt,"kind": 1,"tags": [],"content": "$content","sig": "$sig"}]';
          relays.sendMessage(finalMessage, defaultServerUrl);
          break;

        case 4:
        default:
          userContinue = false;
          //print("number of user events     : $numUserEvents");
          //print("number of feed events    : $numFeedEvents");
          //print("number of other events   : $numOtherEvents");

          String authorName = getAuthorName(userPublickey);
          print("\nFinished fetching feed for user $userPublickey ($authorName), whose contact list has ${contactList.length} profiles.\n ");
          contactList.forEach((x) => stdout.write("${getAuthorName(x)}, "));
          stdout.write("\n");

          print("public key generated = ${getPublicKey(testPrivateKey)}");

          exit(0);
      }
    } // end while
}

Future<void> main(List<String> arguments) async {
    
    final parser = ArgParser()..addOption(requestArg, abbr: 'q')
                              ..addOption(userArg, abbr:"u")
                              ..addOption(lastdaysArg, abbr:"d")
                              ..addOption(relayArg, abbr:"r");
    ArgResults argResults = parser.parse(arguments);

    if( argResults[relayArg] != null) {
      defaultServerUrl =  argResults[relayArg];
      print("Going to use relay: $defaultServerUrl");
    }

    if( argResults[requestArg] != null) {
      stdout.write("Got argument request ${argResults[requestArg]}");
      sendRequest("wss://nostr-pub.wellorder.net", argResults[requestArg]);
      Future.delayed(const Duration(milliseconds: 6000), () {
          Tree node = getTree(getRecievedEvents());
        
          // print all the events in tree form  
          //node.printTree(0, true, DateTime.now().subtract(Duration(days:numLastDays)));
          clearEvents();
          terminalMenuUi(node, []);
      });
      return;
    } 

    if( argResults[userArg] != null) {
      userPublickey = argResults[userArg];
    }
    if( argResults[lastdaysArg] != null) {

      numLastDays =  int.parse(argResults[lastdaysArg]);
      print("Going to show posts for last $numLastDays days");
    }

    // the default in case no arguments are given is:
    // get a user's events, then from its type 3 event, gets events of its follows,
    // then get the events of user-id's mentioned in p-tags of received events
    // then display them all
    getUserEvents(defaultServerUrl, userPublickey, 1000, 0);

    int numUserEvents = 0, numFeedEvents = 0, numOtherEvents = 0;

    const int numWaitSeconds = 2000;
    stdout.write('Waiting for user events to come in....');
    Future.delayed(const Duration(milliseconds: numWaitSeconds), () {
      // count user events
      getRecievedEvents().forEach((element) { element.eventData.kind == 1? numUserEvents++: numUserEvents;});
      stdout.write(".. received ${getRecievedEvents().length} events made by the user\n");

      // get user's feed ( from follows by looking at kind 3 event)
      List<String> contactList = [];
      int latestContactsTime = 0;
      int latestContactIndex = -1;
      for( int i = 0; i < getRecievedEvents().length; i++) {
        var e = getRecievedEvents()[i];
        if( e.eventData.kind == 3 && latestContactsTime < e.eventData.createdAt) {
          latestContactIndex = i;
          latestContactsTime = e.eventData.createdAt;
        }
      }

      if (latestContactIndex != -1) {
          contactList = getContactFeed(getRecievedEvents()[latestContactIndex].eventData.contactList, 300);
          print("number of contacts = ${contactList.length}");
      }

      stdout.write('waiting for feed to come in.....');
      Future.delayed(const Duration(milliseconds: numWaitSeconds * 1), () {

        // count feed events
        getRecievedEvents().forEach((element) { element.eventData.kind == 1? numFeedEvents++: numFeedEvents;});
        numFeedEvents = numFeedEvents - numUserEvents;
        stdout.write("received $numFeedEvents events from the follows\n");

        // get mentioned ptags, and then get the events for those users
        List<String> pTags = getpTags(getRecievedEvents());

        getMultiUserEvents(defaultServerUrl, pTags, 300);
        
        print('Waiting for rest of events to come in....');
        Future.delayed(const Duration(milliseconds: numWaitSeconds * 2), () {
          // count other events
          getRecievedEvents().forEach((element) { element.eventData.kind == 1? numOtherEvents++: numOtherEvents;});
          numOtherEvents = numOtherEvents - numFeedEvents - numUserEvents;
          stdout.write("received $numOtherEvents other events\n");

          Tree node = getTree(getRecievedEvents());
          // display the feed and then call Menu function
          clearEvents();
          terminalMenuUi(node, contactList);

          //exit(0);
        });
      });
    });
}