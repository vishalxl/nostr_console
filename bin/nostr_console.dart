import 'dart:io';
import 'package:bip340/bip340.dart';

import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/tree_ds.dart';
import 'package:nostr_console/relays.dart';

import 'package:nostr_console/console_ui.dart';

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
const String maxDepthArg    = "maxdepth";

void printUsage() {
String usage = """$exename version $version
The nostr console client built using dart.

usage: $exename [OPTIONS] 

  OPTIONS

      --pubkey  <public key>    The hex public key of user whose events and feed are shown. Default is a hard-coded
                                well known private key. When given, posts/replies can't be sent. Same as -p
      --prikey  <private key>   The hex private key of user whose events and feed are shown. Also used to sign events 
                                sent. Default is a hard-coded well known private key. Same as -k
      --relay   <relay wss url> The relay url that is used as main relay. Default is $defaultServerUrl . Same as -r
      --days    <N as num>      The latest number of days for which events are shown. Default is 1. Same as -d
      --request <REQ string>    This request is sent verbatim to the default relay. It can be used to recieve all events
                                from a relay. If not provided, then events for default or given user are shown. Same as -q
  UI Options                                
      --align  <left>           When "left" is given as option to this argument, then the text is aligned to left. By default
                                the posts or text is aligned to the center of the terminal. Same as -a 
      --width  <width as num>   This specifies how wide you want the text to be, in number of columns. Default is $gDefaultTextWidth. 
                                Cant be less than $gMinValidTextWidth. Same as -w
      --maxdepth <depth as num> The maximum depth to which the threads can be displayed. Minimum is $gMinimumDepthAllowed and
                                maximum allowed is $gMaximumDepthAllowed. Same as -m
      --help                    Print this usage message and exit. Same as -h
      
""";
  print(usage);
}

Future<void> main(List<String> arguments) async {
    
    final parser = ArgParser()..addOption(requestArg, abbr: 'q') ..addOption(pubkeyArg, abbr:"p")..addOption(prikeyArg, abbr:"k")
                              ..addOption(lastdaysArg, abbr:"d") ..addOption(relayArg, abbr:"r")
                              ..addFlag(helpArg, abbr:"h", defaultsTo: false)..addOption(alignArg, abbr:"a")
                              ..addOption(widthArg, abbr:"w")..addOption(maxDepthArg, abbr:"m");

    try {
      ArgResults argResults = parser.parse(arguments);
      if( argResults[helpArg]) {
        printUsage();
        return;
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

      // can be computed only after textWidth has been found
      gNumLeftMarginSpaces = (stdout.terminalColumns - gTextWidth )~/2;
      
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

      if( argResults[requestArg] != null) {
        stdout.write("Got argument request ${argResults[requestArg]}");
        sendRequest(defaultServerUrl, argResults[requestArg]);
        Future.delayed(const Duration(milliseconds: 6000), () {
            Tree node = getTree(getRecievedEvents());
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

    // the default in case no arguments are given is:
    // get a user's events, then from its type 3 event, gets events of its follows,
    // then get the events of user-id's mentioned in p-tags of received events
    // then display them all
    getUserEvents(defaultServerUrl, userPublicKey, 1000, 0);

    int numUserEvents = 0, numFeedEvents = 0, numOtherEvents = 0;

    const int numWaitSeconds = 2500;
    stdout.write('Waiting for user events to come in.....');
    Future.delayed(const Duration(milliseconds: numWaitSeconds), () {
      // count user events
      getRecievedEvents().forEach((element) { element.eventData.kind == 1? numUserEvents++: numUserEvents;});
      stdout.write("...received ${getRecievedEvents().length} events made by the user\n");

      // get the latest kind 3 event for the user, which lists his 'follows' list
      List<String> contactList = [];
      int latestContactsTime = 0, latestContactIndex = -1;
      for( int i = 0; i < getRecievedEvents().length; i++) {
        var e = getRecievedEvents()[i];
        if( e.eventData.kind == 3 && latestContactsTime < e.eventData.createdAt) {
          latestContactIndex = i;
          latestContactsTime = e.eventData.createdAt;
        }
      }

      // if contact list was found, get user's feed 
      if (latestContactIndex != -1) {
          contactList = getContactFeed(getRecievedEvents()[latestContactIndex].eventData.contactList, 300);
      }

      stdout.write('Waiting for feed to come in...............');
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
          clearEvents();
          // call the mein UI function
          mainMenuUi(node, contactList);
        });
      });
    });
}