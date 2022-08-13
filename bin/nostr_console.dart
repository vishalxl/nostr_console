import 'dart:io';
import 'package:bip340/bip340.dart';
import 'package:nostr_console/nostr_console_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for the utf8.encode method

// name of executable
String exename = "nostr_console";
String version = "0.0.1";

// well known disposable test private key
const String testPrivateKey = "9d00d99c8dfad84534d3b395280ca3b3e81be5361d69dc0abf8e0fdf5a9d52f9";
const String testPublicKey  = "e8caa2028a7090ffa85f1afee67451b309ba2f9dee655ec8f7e0a02c29388180";
String userPrivateKey = testPrivateKey;
String userPublicKey  = testPublicKey;

// program arguments
const String requestArg  = "request";
const String prikeyArg   = "prikey";
const String lastdaysArg = "days";
const String relayArg    = "relay";
const String helpArg     = "help";

// By default the threads that were started in last one day are shown
// this can be changed with 'days' command line argument
int numLastDays = 1; 

void printUsage() {
String usage = """$exename version $version

usage: $exename [OPTIONS] 

  OPTIONS

      --prikey  <private key>   The hex private key of user whose events and feed are shown. Also used to sign events 
                                sent. Default is a hard-coded well known private key. Same as -p
      --relay   <relay wss url> The relay url that is used as main relay. Default is $defaultServerUrl . Same as -r
      --days    <N>             The latest number of days for which events are shown. Default is 1. Same as -d
      --request <REQ string>    This request is sent verbatim to the default relay. It can be used to recieve all events
                                from a relay. If not provided, then events for default or given user are shown. Same as -q
      --help                    Print this usage message and exit. Same as -h
      
""";
  print(usage);
}

int showMenu(List<String> menuOptions) {
  while(true) {
    //print("in showmenu while");
    for(int i = 0; i < menuOptions.length;i++) {
      print("    ${i+1}. ${menuOptions[i]}");
    }

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

Future<void> terminalMenuUi(Tree node, var contactList) async {
    bool userContinue = true;
    while(userContinue) {

      print('\nPick an option by typing the corresponding\nnumber and then pressing <enter>:');
      int option = showMenu(['Display events',    // 1 
                             'Post/Reply',        // 2
                             'Exit']);            // 3
      print('You picked: $option');
      switch(option) {
        case 1:
          //print("in display events option");
          node.printTree(0, true, DateTime.now().subtract(Duration(days:numLastDays)));
          break;

        case 2:
          print("Type comment to post/reply: ");
          String? $contentVar = stdin.readLineSync();
          String content = $contentVar??"";
          if( content == "") {
            break;
          }

          print("Type id of event to reply to ( leave blank if you want to make a post): ");
          String? $replyToVar = stdin.readLineSync();
          String replyToId = $replyToVar??"";
          String strTags = node.getTagsFromEvent(replyToId);
          int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
          
          String id = getShaId(userPublicKey, createdAt, strTags, content);
          String sig = sign(userPrivateKey, id, "12345612345612345612345612345612");

          String toSendMessage = '["EVENT", {"id": "$id","pubkey": "$userPublicKey","created_at": $createdAt,"kind": 1,"tags": [$strTags],"content": "$content","sig": "$sig"}]';
          relays.sendMessage(toSendMessage, defaultServerUrl);
          break;

        case 3:
        default:
          userContinue = false;
          //print("number of user events     : $numUserEvents");
          //print("number of feed events    : $numFeedEvents");
          //print("number of other events   : $numOtherEvents");

          String authorName = getAuthorName(userPublicKey);
          print("\nFinished fetching feed for user $userPublicKey ($authorName), whose contact list has ${contactList.length} profiles.\n ");
          contactList.forEach((x) => stdout.write("${getAuthorName(x)}, "));
          stdout.write("\n");
          exit(0);
      }
      
      // need a bit of wait to give other events to execute, so do a delay, which allows
      // relays to recieve and handle new events
      const int waitMilliSeconds = 400;
      Future.delayed(const Duration(milliseconds: waitMilliSeconds), ()  {
        print("\n\nNumber of new events = ${getRecievedEvents().length}");
        node.insertEvents(getRecievedEvents());
        clearEvents();
      });

      Future<void> foo() async {
        await Future.delayed(Duration(milliseconds: waitMilliSeconds + 100));
        return;
      }
      await foo();

    } // end while
}

Future<void> main(List<String> arguments) async {
    
    final parser = ArgParser()..addOption(requestArg, abbr: 'q')
                              ..addOption(prikeyArg, abbr:"p")
                              ..addOption(lastdaysArg, abbr:"d")
                              ..addOption(relayArg, abbr:"r")
                              ..addFlag(helpArg, abbr:"h", defaultsTo: false)..allowsAnything;

    try {
      ArgResults argResults = parser.parse(arguments);
      if( argResults[helpArg]) {
        printUsage();
        return;
      }

      if( argResults[relayArg] != null) {
        defaultServerUrl =  argResults[relayArg];
        print("Going to use relay: $defaultServerUrl");
      }

      if( argResults[prikeyArg] != null) {
        userPrivateKey = argResults[prikeyArg];
        userPublicKey = getPublicKey(userPrivateKey);
      }
      if( argResults[lastdaysArg] != null) {

        numLastDays =  int.parse(argResults[lastdaysArg]);
        print("Going to show posts for last $numLastDays days");
      }

      if( argResults[requestArg] != null) {
        stdout.write("Got argument request ${argResults[requestArg]}");
        sendRequest("wss://nostr-pub.wellorder.net", argResults[requestArg]);
        Future.delayed(const Duration(milliseconds: 6000), () {
            Tree node = getTree(getRecievedEvents());
          
            // print all the events in tree form  
            clearEvents();
            terminalMenuUi(node, []);
        });
        return;
      } 
    } on FormatException catch (e) {
      print(e.message);
      return;
    } on Exception catch (e) {
      print(e);
      return;
    }    

    // the default in case no arguments are given is:
    // get a user's events, then from its type 3 event, gets events of its follows,
    // then get the events of user-id's mentioned in p-tags of received events
    // then display them all
    getUserEvents(defaultServerUrl, userPublicKey, 1000, 0);

    int numUserEvents = 0, numFeedEvents = 0, numOtherEvents = 0;

    const int numWaitSeconds = 2000;
    stdout.write('Waiting for user events to come in.....');
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
        
        stdout.write('Waiting for rest of events to come in.....');
        Future.delayed(const Duration(milliseconds: numWaitSeconds * 2), () {
          // count other events
          getRecievedEvents().forEach((element) { element.eventData.kind == 1? numOtherEvents++: numOtherEvents;});
          numOtherEvents = numOtherEvents - numFeedEvents - numUserEvents;
          stdout.write("received $numOtherEvents other events\n");

          Tree node = getTree(getRecievedEvents());
          // display the feed and then call Menu function
          clearEvents();
          terminalMenuUi(node, contactList);
        });
      });
    });
}