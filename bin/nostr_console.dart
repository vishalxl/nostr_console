import 'dart:io';
import 'package:bip340/bip340.dart';

import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:nostr_console/console_ui.dart';
import 'package:nostr_console/settings.dart';
import 'package:args/args.dart';

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

const String translateArg = "translate";
const String colorArg     = "color";

void printUsage() {
  print(gUsage);
}

Future<void> main(List<String> arguments) async {
    final parser = ArgParser()..addOption(requestArg, abbr: 'q') ..addOption(pubkeyArg, abbr:"p")..addOption(prikeyArg, abbr:"k")
                              ..addOption(lastdaysArg, abbr:"d") ..addOption(relayArg, abbr:"r")
                              ..addFlag(helpArg, abbr:"h", defaultsTo: false)..addOption(alignArg, abbr:"a")
                              ..addOption(widthArg, abbr:"w")..addOption(maxDepthArg, abbr:"m")
                              ..addOption(eventFileArg, abbr:"f", defaultsTo: gDefaultEventsFilename)..addFlag(disableFileArg, abbr:"n", defaultsTo: false)
                              ..addFlag(translateArg, abbr: "t", defaultsTo: false)
                              ..addOption(colorArg, abbr:"c");
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
        userPrivateKey = "";
        print("Going to use public key $userPublicKey. You will not be able to send posts/replies.");
      }
      if( argResults[prikeyArg] != null) {
        userPrivateKey = argResults[prikeyArg];
        userPublicKey = getPublicKey(userPrivateKey);
        print("Going to use the provided private key");
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
        List<Event> eventsFromFile = readEventsFromFile(gEventsFilename);
        setRelaysIntialEvents(eventsFromFile);
        eventsFromFile.forEach((element) { element.eventData.kind == 1? numFileEvents++: numFileEvents;});
        print("read $numFileEvents posts from file $gEventsFilename");
      }
      if( argResults[requestArg] != null) {
        stdout.write('Sending request and waiting for events...');
        sendRequest(gListRelayUrls, argResults[requestArg]);
        Future.delayed(const Duration(milliseconds: numWaitSeconds * 2), () {
            List<Event> receivedEvents = getRecievedEvents();
            stdout.write("received ${receivedEvents.length - numFileEvents} events\n");

            // remove bots
            receivedEvents.removeWhere((e) => gBots.contains(e.eventData.pubkey));
            
            // create tree
            Future<Tree>  node = getTree(getRecievedEvents());
            //clearEvents(); // cause we have consumed them above
            node.then((value) { 
                clearEvents();
                mainMenuUi(value, []); 
              });
            // call main menu
            
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

    getUserEvents(gListRelayUrls, userPublicKey, 3000, 0);
  
    // the default in case no arguments are given is:
    // get a user's events, then from its type 3 event, gets events of its follows,
    // then get the events of user-id's mentioned in p-tags of received events
    // then display them all
    stdout.write('Waiting for user posts to come in.....');
    Future.delayed(const Duration(milliseconds: numWaitSeconds), () {
      // count user events
      getRecievedEvents().forEach((element) { element.eventData.kind == 1? numUserEvents++: numUserEvents;});
      numUserEvents -= numFileEvents;
      stdout.write("...received $numUserEvents posts made by the user\n");

      // get the latest kind 3 event for the user, which lists his 'follows' list
      Event? contactEvent = getContactEvent(getRecievedEvents(), userPublicKey);

      // if contact list was found, get user's feed, and keep the contact list for later use 
      List<String> contactList = [];
      if (contactEvent != null ) {
        if(gDebug > 0) print("In main: found contact list: \n ${contactEvent.originalJson}");
        contactList = getContactFeed(gListRelayUrls, contactEvent.eventData.contactList, 4000);

        if( !gContactLists.containsKey(userPublicKey)) {
          gContactLists[userPublicKey] = contactEvent.eventData.contactList;
        }
      } else {
        if( gDebug > 0) print( "could not find contact list");
      }
      
      stdout.write('Waiting for feed to come in..............');
      Future.delayed(const Duration(milliseconds: numWaitSeconds * 1), () {

        // count feed events
        getRecievedEvents().forEach((element) { element.eventData.kind == 1? numFeedEvents++: numFeedEvents;});
        numFeedEvents = numFeedEvents - numUserEvents - numFileEvents;
        stdout.write("received $numFeedEvents posts from the follows\n");

        // get mentioned ptags, and then get the events for those users
        List<String> pTags = getpTags(getRecievedEvents(), 300);
        getMultiUserEvents(defaultServerUrl, pTags, 5000);
        
        stdout.write('Waiting for rest of posts to come in.....');
        Future.delayed(const Duration(milliseconds: numWaitSeconds * 2), () {
          // count other events
          getRecievedEvents().forEach((element) { element.eventData.kind == 1? numOtherEvents++: numOtherEvents;});
          numOtherEvents = numOtherEvents - numFeedEvents - numUserEvents - numFileEvents;
          stdout.write("received $numOtherEvents other posts\n");

          // get all events in Tree form
          Future<Tree> node = getTree(getRecievedEvents());

          // call the mein UI function
          node.then((value) {
            clearEvents();
            mainMenuUi(value, contactList);
          });
          
        });
      });
    });
}