import 'dart:io';
import 'package:translator/translator.dart';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:nostr_console/console_ui.dart';
import 'package:nostr_console/settings.dart';
import 'package:nostr_console/utils.dart';
import 'package:nostr_console/user.dart';

import 'package:args/args.dart';
import 'package:logging/logging.dart';

// program arguments
const String pubkeyArg   = "pubkey";
const String prikeyArg   = "prikey";
const String lastdaysArg = "days";
const String relayArg    = "relay";
const String requestArg  = "request";
const String helpArg     = "help";
const String versionArg  = "version";
const String alignArg    = "align"; // can only be "left"
const String widthArg    = "width";
const String maxDepthArg = "maxdepth";
const String eventFileArg = "file";
const String disableFileArg = "disable-file";
const String difficultyArg  = "difficulty";
const String translateArg = "translate";
const String colorArg     = "color";
const String overWriteFlag = "overwrite";
const String locationArg = "location";

Future<void> main(List<String> arguments) async {
      
    final parser = ArgParser()..addOption(requestArg, abbr: 'q') ..addOption(pubkeyArg, abbr:"p")..addOption(prikeyArg, abbr:"k")
                              ..addOption(lastdaysArg, abbr:"d") ..addOption(relayArg, abbr:"r")
                              ..addFlag(helpArg, abbr:"h", defaultsTo: false)
                              ..addFlag(versionArg, abbr:"v", defaultsTo: false)
                              ..addOption(alignArg, abbr:"a")
                              ..addOption(widthArg, abbr:"w")..addOption(maxDepthArg, abbr:"m")
                              ..addOption(eventFileArg, abbr:"f", defaultsTo: gDefaultEventsFilename)..addFlag(disableFileArg, abbr:"s", defaultsTo: false)
                              ..addFlag(translateArg, abbr: "t", defaultsTo: false)
                              ..addOption(colorArg, abbr:"c")
                              ..addOption(difficultyArg, abbr:"y")
                              ..addFlag(overWriteFlag, abbr:"e", defaultsTo: false)
                              ..addOption(locationArg, abbr:"l")
                              ..addFlag("debug");
    try {
      ArgResults argResults = parser.parse(arguments);
      if( argResults[helpArg]) {
        printUsage();
        return;
      }

      if( argResults[versionArg]) {
        printVersion();
        return;
      }

      Logger.root.level = Level.ALL; // defaults to Level.INFO
      DateTime appStartTime = DateTime.now();
      print("app start time: $appStartTime");
      Logger.root.onRecord.listen((record) {
        print('${record.level.name}: ${record.time.difference(appStartTime)}: ${record.message}');
      });

      // start application
      printIntro("Nostr");

      if( argResults["debug"]) {
        gDebug = 1;
      }

      if( argResults[overWriteFlag]) {
        print("Going to overwrite file at the end of program execution.");
        gOverWriteFile = true;
      }


      if( argResults[translateArg]) {
        gTranslate = true;
        print("Going to translate comments in last $gNumTranslateDays days using Google translate service");
        translator = GoogleTranslator();
      }

      // get location of user if given
      if( argResults[locationArg] != null) {
        gUserLocation = argResults[locationArg];
        userPrivateKey = "";
      }

      if( gUserLocation.length > 0){ 
        print("Going to add $gUserLocation as the location tag with each post.");
      }

      if( argResults[pubkeyArg] != null) {
        userPublicKey = argResults[pubkeyArg];
        if( userPublicKey.length != 64){ 
          print("Length of provided public key should be 64. Exiting.");
          return;
        }
        userPrivateKey = "";
      }

      // process private key argument, and it overrides what's given in pub key argument, if any pubkey is given
      if( argResults[prikeyArg] != null) {
        userPrivateKey = argResults[prikeyArg];
        if( userPrivateKey.length != 64){ 
          print("Length of provided private key should be 64. Exiting.");
          return;
        }
        userPublicKey = myGetPublicKey(userPrivateKey);
        print("Going to use the provided private key");
      }

      // write informative message in case user is not using proper keys
      if( userPublicKey == gDefaultPublicKey) {
        print("You should ideally create your own private key and use it with ${gWarningColor}--prikey$gColorEndMarker program argument. ");
        print("Create a private key from ${gWarningColor}astral.ninja, @damusapp, or even from command line using `openssl rand -hex 32`.$gColorEndMarker.\n");
      }

      // handle relay related argument
      if( argResults[relayArg] != null) {
        Set<String> userRelayList = Set.from(argResults[relayArg].split(","));
        Set<String> parsedRelays = {};
        userRelayList.forEach((relay) {
          if(relay.startsWith(RegExp(r'^ws[s]?:\/\/'))) {
            parsedRelays.add(relay);
          } else {
            printWarning("The provided relay entry: \"$relay\" does not start with ws:// or wss://, omitting");
          }
        });

        // verify that there is at least one valid relay they provided, otherwise keep defaults
        if (parsedRelays.length > 0) {
          gListRelayUrls1 = parsedRelays;
          defaultServerUrl = gListRelayUrls1.first;
        } else {
          print("No valid relays were provided, using the default relay list");
        }
      }
      printSet( gListRelayUrls1, "Primary relays that will be used: ", ",");
      print("From among them, default relay: $defaultServerUrl");
      
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

        var terminalColumns = gDefaultTextWidth;
        if( stdout.hasTerminal )
          terminalColumns = stdout.terminalColumns;

        // can be computed only after textWidth has been found
        if( gTextWidth > terminalColumns) {
          gTextWidth = terminalColumns - 5;
        }
        gNumLeftMarginSpaces = (terminalColumns - gTextWidth )~/2;
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
        if( gColorMapForArguments.containsKey(colorGiven)) {
            String color = gColorMapForArguments[colorGiven]??"";
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
      }

      Set<Event> initialEvents = {}; // collect all events here and then create tree out of them

      if( gEventsFilename != "") {
        stdout.write('Reading events from ${whetherDefault}file.......');

        // read file events and give the events to relays from where they're picked up later
        initialEvents = await readEventsFromFile(gEventsFilename);

        // count events
        initialEvents.forEach((element) { numFileEvents++;});
        print("read $numFileEvents events from file $gEventsFilename");
      }

      int limitSelfEvents = 200;
      int limitOthersEvents = 4;
      int limitPerSubscription = gLimitPerSubscription;

      // if more than 1000 posts have already been read from the file, then don't get too many day's events. Only for last 3 days.
      if(numFileEvents > 1000) {
        limitPerSubscription = 5000;
        limitSelfEvents = 10;
        limitOthersEvents = 3;
        gDefaultNumWaitSeconds = gDefaultNumWaitSeconds ~/5;
      } else {
        printInfoForNewUser();
      }

      // process request string. If this is blank then the application only reads from file and does not connect to internet. 
      if( argResults[requestArg] != null) {
        int numWaitSeconds = gDefaultNumWaitSeconds;

        if( argResults[requestArg] != "") {
          stdout.write('Sending request ${argResults[requestArg]} and waiting for events...');
          sendRequest(gListRelayUrls1, argResults[requestArg]);
        } else {
          numWaitSeconds = 0;
          gEventsFilename = ""; // so it wont write it back to keep it faster ( and since without internet no new event is there to be written )
        }

        if( userPublicKey!= "") {
          getUserEvents(gListRelayUrls1, userPublicKey, limitPerSubscription, getSecondsDaysAgo(limitSelfEvents));
          getMentionEvents(gListRelayUrls1, {userPublicKey}, limitPerSubscription, getSecondsDaysAgo(limitSelfEvents), "#p"); 
        }
        
        Future.delayed(Duration(milliseconds: numWaitSeconds), () {
            Set<Event> receivedEvents = getRecievedEvents();

            initialEvents.addAll(receivedEvents);

            // Create tree from all events read form file
            Store node = getTree(initialEvents);
            
            clearEvents();
            if( gDebug > 0) stdout.write("Total events of kind 1 in created tree: ${node.count()} events\n");
            gStore = node;
            mainMenuUi(node);            
        });
        return;
      } 

      // the default in case no arguments are given is:
      // get a user's events with all default users events
      // get mentions for user
      // get all kind 0, 3, 4x, 14x events
      
      // then get the events of user-id's mentioned in p-tags of received events and the contact list
      // then display them all

      // get event for user
      if( userPublicKey!= "") {
        getUserEvents(gListRelayUrls1, userPublicKey, limitPerSubscription, getSecondsDaysAgo(limitSelfEvents));
        getMentionEvents(gListRelayUrls1, {userPublicKey}, limitPerSubscription, getSecondsDaysAgo(limitSelfEvents), "#p"); 
      }
      //getKindEvents([gSecretMessageKind], gListRelayUrls1, limitPerSubscription, getSecondsDaysAgo( limitSelfEvents)); 

      Set<String> usersFetched = {userPublicKey};
      // remove user from default list if he exists in it. because theyv'e already been fetched. 
      gDefaultFollows = gDefaultFollows.difference(usersFetched);

      // get other user events
      getMultiUserEvents(gListRelayUrls1, gDefaultFollows, 4 * limitPerSubscription, getSecondsDaysAgo(limitOthersEvents));
      usersFetched = usersFetched.union(gDefaultFollows);

      // get group and meta info events
      getKindEvents([40, 41], gListRelayUrls1, limitPerSubscription, getSecondsDaysAgo(limitSelfEvents));
      getKindEvents([42], gListRelayUrls1, 3 * limitPerSubscription, getSecondsDaysAgo(4));

      getMultiUserEvents(gListRelayUrls1, usersFetched, 4 *  limitPerSubscription, getSecondsDaysAgo(limitSelfEvents), {0,3});

      stdout.write('Waiting for user posts to come in.....');
      Future.delayed( Duration(milliseconds: gDefaultNumWaitSeconds), () {
        //print("total users fetched: ${usersFetched.length}");

        initialEvents.addAll(getRecievedEvents());
        clearEvents();

        initialEvents.forEach((element) { element.eventData.kind == 1? numUserPosts++: numUserPosts;});
        numUserPosts -= numFilePosts;
        stdout.write("...done\n");//received $numUserPosts new posts made by the user\n");

        initialEvents.forEach((e) => processKind3Event(e)); // first process the kind 3 event
        
        Set<String> contacts = {};
        if( userPublicKey != "") {
          // get the latest kind 3 event for the user, which lists his 'follows' list
          Event? contactEvent = getContactEvent(userPublicKey);

          // if contact list was found, get user's feed; also get some default contacts
          if (contactEvent != null ) {
            if(gDebug > 0) print("In main: found contact list: \n ${contactEvent.originalJson}");
            contactEvent.eventData.contactList.forEach((contact) {
              contacts.add(contact.id);
            });
            contacts = contacts.difference(usersFetched); // remove already fetched users from this list

            getContactFeed(gListRelayUrls1, contacts, 3 * gLimitPerSubscription, getSecondsDaysAgo( limitOthersEvents));
            usersFetched = usersFetched.union(contacts);
          } else {
            print("Could not find your contact list.");
          }
        }

        // fetch extra events for people who don't have too large a follow list
        if( usersFetched.length < gMaxPtagsToGet * 2 ) {
          // calculate top mentioned ptags, and then get the events for those users
          Set<String> pTags = getpTags(initialEvents, gMaxPtagsToGet);
          pTags = pTags.difference(usersFetched); 

          getMultiUserEvents(gListRelayUrls1, pTags, 4 * gLimitPerSubscription, getSecondsDaysAgo(limitOthersEvents));
          usersFetched = usersFetched.union(pTags);
        }

        // get events from channels of user
        Set<String> userChannels = getUserChannels(initialEvents, userPublicKey);
        //getMentionEvents(gListRelayUrls1, userChannels, limitPerSubscription, getSecondsDaysAgo(limitSelfEvents), "#e"); 

        stdout.write('Waiting for feed to come in..............');
        Future.delayed(Duration(milliseconds: gDefaultNumWaitSeconds * 1), () {

            initialEvents.addAll(getRecievedEvents());
            clearEvents();

            stdout.write("done\n");
            if( gDebug > 0) log.info("Received ptag events events.");

            // Creat tree from all events read form file
            Store node = getTree(initialEvents);
            gStore = node;
            
            clearEvents();
            mainMenuUi(node);
          });
      });
    } on FormatException catch (e) {
      print(e.message);
      return;
    } on Exception catch (e) {
      print(e);
      return;
    }    
}
