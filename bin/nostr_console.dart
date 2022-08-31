import 'dart:io';
import 'package:bip340/bip340.dart';

import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:nostr_console/console_ui.dart';
import 'package:nostr_console/settings.dart';
import 'package:args/args.dart';
import 'package:logging/logging.dart';

// program arguments
const String pubkeyArg   = "pubkey";
const String prikeyArg   = "prikey";
const String lastdaysArg = "days";
const String relayArg    = "relay";
const String requestArg  = "request";
const String helpArg     = "help";
const String alignArg    = "align"; // can be "left"
const String widthArg    = "width";
const String maxDepthArg = "maxdepth";
const String eventFileArg = "file";
const String disableFileArg = "disable-file";
const String difficultyArg  = "difficulty";

const String translateArg = "translate";
const String colorArg     = "color";

void printUsage() {
  print(gUsage);
}

Future<void> main(List<String> arguments) async {
    printIntro("Nostr");
    Logger.root.level = Level.ALL; // defaults to Level.INFO
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
      
    final parser = ArgParser()..addOption(requestArg, abbr: 'q') ..addOption(pubkeyArg, abbr:"p")..addOption(prikeyArg, abbr:"k")
                              ..addOption(lastdaysArg, abbr:"d") ..addOption(relayArg, abbr:"r")
                              ..addFlag(helpArg, abbr:"h", defaultsTo: false)..addOption(alignArg, abbr:"a")
                              ..addOption(widthArg, abbr:"w")..addOption(maxDepthArg, abbr:"m")
                              ..addOption(eventFileArg, abbr:"f", defaultsTo: gDefaultEventsFilename)..addFlag(disableFileArg, abbr:"s", defaultsTo: false)
                              ..addFlag(translateArg, abbr: "t", defaultsTo: false)
                              ..addOption(colorArg, abbr:"c")
                              ..addOption(difficultyArg, abbr:"y");
    try {
      ArgResults argResults = parser.parse(arguments);
      if( argResults[helpArg]) {
        printUsage();
        return;
      }

      if( argResults[translateArg]) {
        gTranslate = true;
        print("Going to translate comments in last $gNumTranslateDays days using Google translate service");
      }

      if( argResults[pubkeyArg] != null) {
        userPublicKey = argResults[pubkeyArg];
        if( userPublicKey.length != 64){ 
          print("Length of provided public key should be 64. Exiting.");
          return;
        }
        userPrivateKey = "";
        print("Going to use public key $userPublicKey. You will not be able to send posts/replies.");
      }
      if( argResults[prikeyArg] != null) {
        userPrivateKey = argResults[prikeyArg];
        if( userPrivateKey.length != 64){ 
          print("Length of provided private key should be 64. Exiting.");
          return;
        }
        userPublicKey = getPublicKey(userPrivateKey);
        print("Going to use the provided private key");
      }

      // write informative message in case user is using the default private key
      if( userPrivateKey == gDefaultPrivateKey) {
        print("${gWarningColor}You seem to be using the default private key, which comes bundled with this $exename and is used by all users of this program$gColorEndMarker");
        print("You can also create your own private key and use it with ${gWarningColor}--prikey$gColorEndMarker program argument. ");
        print("You can create your own private key from ${gWarningColor}astral.ninja or branle.netlify.app$gColorEndMarker, or other such tools.\n");
      }

      if( argResults[relayArg] != null) {
        defaultServerUrl =  argResults[relayArg];
        print("Going to use relay: $defaultServerUrl");
      }
      if( argResults[lastdaysArg] != null) {
        gNumLastDays =  int.parse(argResults[lastdaysArg]);
        print("Going to show posts for last $gNumLastDays days");
      }
      if( argResults[widthArg] != null) {
        int tempTextWidth = int.parse(argResults[widthArg]);
        if( tempTextWidth < gMinValidTextWidth ) {
          print("Text-width cannot be less than $gMinValidTextWidth. Going to use the defalt value of $gTextWidth");
        } else {
          gTextWidth = tempTextWidth;
          print("Going to use $gTextWidth columns for text on screen.");
        }
      }
      try {
        // can be computed only after textWidth has been found
        if( gTextWidth > stdout.terminalColumns) {
          gTextWidth = stdout.terminalColumns - 5;
        }
        gNumLeftMarginSpaces = (stdout.terminalColumns - gTextWidth )~/2;
      } on StdoutException catch (e) {
        print("Cannot find terminal size. Left aligning by default.");
        if( gDebug > 0) log.info("${e.message}");
        gNumLeftMarginSpaces = 0;
      }
      // undo above if left option is given
      if( argResults[alignArg] != null ) {
        if( argResults[alignArg] == "left" ) {
          print("Going to align to left.");
          gAlignment = "left";
          gNumLeftMarginSpaces = 0;
        }
      }
      if( argResults[maxDepthArg] != null) {
        int tempMaxDepth = int.parse(argResults[maxDepthArg]);
        if( tempMaxDepth < gMinimumDepthAllowed || tempMaxDepth > gMaximumDepthAllowed) {
          print("Maximum depth cannot be less than $gMinimumDepthAllowed and cannot be more than $gMaximumDepthAllowed. Going to use the default maximum depth, which is $gDefaultMaxDepth.");
        } else {
          maxDepthAllowed = tempMaxDepth;
          print("Going to take threads to maximum depth of $gNumLastDays days");
        }
      }

      if( argResults[colorArg] != null) {
        String colorGiven = argResults[colorArg].toString().toLowerCase();
        if( gColorMap.containsKey(colorGiven)) {
            String color = gColorMap[colorGiven]??"";
            if( color == "") {
              print("Invalid color.");
            } else
            {
              gCommentColor = color;
              stdout.write("Going to use color $colorGiven for text");
              if( colorGiven == "cyan") {
                gNotificationColor = greenColor;
                stdout.write(". Green as notification color");
              }
              stdout.write(".\n");
            }
        } else {
           print("Invalid color.");
        }
      }

      if( argResults[difficultyArg] != null) {
        gDifficulty =  int.parse(argResults[difficultyArg]);

        if( gDifficulty > gMaxDifficultyAllowed) {
          print("Difficulty cannot be larger than $gMaxDifficultyAllowed. Going to use difficulty of $gMaxDifficultyAllowed");
          gDifficulty = gMaxDifficultyAllowed;
        }
        else {
          if( gDifficulty < 0) {
            print("Difficulty cannot be less than 0. Going to use difficulty of 0 bits.");
          } else {
            print("Going to use difficulty of value: $gDifficulty bits");
          }
        }
      }


      if( argResults[disableFileArg]) {
        gEventsFilename = "";
        print("Not going to use any file to read/write events.");
      }

      String whetherDefault = "the given ";
      if( argResults[eventFileArg] != null && !argResults[disableFileArg]) {
        if( gDefaultEventsFilename == argResults[eventFileArg]) {
          whetherDefault = " default  ";
        }

        gEventsFilename =  argResults[eventFileArg];
        if( gEventsFilename != "") { 
          print("Going to use ${whetherDefault}file to read from and store events: $gEventsFilename");
        }
      }

      if( gEventsFilename != "") {
        print("\n");
        stdout.write('Reading events from ${whetherDefault}file.......');

        // read file events and give the events to relays from where they're picked up later
        Set<Event> eventsFromFile = await readEventsFromFile(gEventsFilename);
        setRelaysIntialEvents(eventsFromFile);

        // count events
        eventsFromFile.forEach((element) { element.eventData.kind == 1? numFileEvents++: numFileEvents;});
        print("read $numFileEvents posts from file $gEventsFilename");
      }

      // process request string. If this is blank then the application only reads from file and does not connect to internet. 
      if( argResults[requestArg] != null) {
        int numWaitSeconds = gDefaultNumWaitSeconds;

        if( argResults[requestArg] != "") {
          stdout.write('Sending request ${argResults[requestArg]} and waiting for events...');
          sendRequest(gListRelayUrls, argResults[requestArg]);
        } else {
          numWaitSeconds = 0;
          gEventsFilename = ""; // so it wont write it back to keep it faster ( and since without internet no new event is there to be written )
        }
        
        Future.delayed(Duration(milliseconds: numWaitSeconds * 2), () {
            Set<Event> receivedEvents = getRecievedEvents();
            stdout.write("received ${receivedEvents.length - numFileEvents} events\n");

            // create tree: will process reactions, remove bots, and then create main tree
            Tree  node = getTree(getRecievedEvents());
            
            //clearEvents(); // cause we have consumed them above
              if( gDebug > 0) stdout.write("Total events of kind 1 in created tree: ${node.count()} events\n");
              clearEvents();

              mainMenuUi(node, []);            
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

    getUserEvents(gListRelayUrls, userPublicKey, gLimitPerSubscription, getSecondsDaysAgo(gDaysToGetEventsFor));
  
    // the default in case no arguments are given is:
    // get a user's events, then from its type 3 event, gets events of its follows,
    // then get the events of user-id's mentioned in p-tags of received events
    // then display them all
    stdout.write('Waiting for user posts to come in.....');
    Future.delayed(const Duration(milliseconds: gDefaultNumWaitSeconds), () {
      // count user events
      getRecievedEvents().forEach((element) { element.eventData.kind == 1? numUserEvents++: numUserEvents;});
      numUserEvents -= numFileEvents;
      stdout.write("...received $numUserEvents posts made by the user\n");
      if( gDebug > 0) log.info("Received user events.");

      // get the latest kind 3 event for the user, which lists his 'follows' list
      Event? contactEvent = getContactEvent(getRecievedEvents(), userPublicKey);

      // if contact list was found, get user's feed, and keep the contact list for later use 
      List<String> contactList = [];
      if (contactEvent != null ) {
        if(gDebug > 0) print("In main: found contact list: \n ${contactEvent.originalJson}");
        contactList = getContactFeed(gListRelayUrls, contactEvent.eventData.contactList, gLimitPerSubscription, getSecondsDaysAgo(gDaysToGetEventsFor));

        if( !gContactLists.containsKey(userPublicKey)) {
          gContactLists[userPublicKey] = contactEvent.eventData.contactList;
        }
      } else {
        if( gDebug > 0) print( "could not find contact list");
      }
      
      stdout.write('Waiting for feed to come in..............');
      Future.delayed(const Duration(milliseconds: gDefaultNumWaitSeconds * 1), () {

        // count feed events
        getRecievedEvents().forEach((element) { element.eventData.kind == 1? numFeedEvents++: numFeedEvents;});
        numFeedEvents = numFeedEvents - numUserEvents - numFileEvents;
        stdout.write("received $numFeedEvents posts from the follows\n");
        if( gDebug > 0)  log.info("Received feed.");

        // get mentioned ptags, and then get the events for those users
        List<String> pTags = getpTags(getRecievedEvents(), gMaxPtagsToGet);
        getMultiUserEvents(gListRelayUrls, pTags, gLimitPerSubscription, getSecondsDaysAgo(gDaysToGetEventsFor));
        
        stdout.write('Waiting for rest of posts to come in.....');
        Future.delayed(const Duration(milliseconds: gDefaultNumWaitSeconds * 2), () {

          // count other events
          getRecievedEvents().forEach((element) { element.eventData.kind == 1? numOtherEvents++: numOtherEvents;});
          numOtherEvents = numOtherEvents - numFeedEvents - numUserEvents - numFileEvents;
          stdout.write("received $numOtherEvents other posts\n");
          if( gDebug > 0) log.info("Received ptag events events.");

          // get all events in Tree form
          Tree node = getTree(getRecievedEvents());

          // call the mein UI function
          clearEvents();
          mainMenuUi(node, contactList);
        });
      });
    });
}