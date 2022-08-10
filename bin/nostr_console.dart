import 'dart:io';
import 'package:nostr_console/nostr_console_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:args/args.dart';


var    userPublickey = "3235036bd0957dfb27ccda02d452d7c763be40c91a1ac082ba6983b25238388c"; // vishalxl
//var    userPublickey = "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245"; // jb55
//var    userPublickey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"; // fiatjaf
// ed1d0e1f743a7d19aa2dfb0162df73bacdbc699f67cc55bb91a98c35f7deac69 melvin
//var    userPublickey = "52b4a076bcbbbdc3a1aefa3735816cf74993b1b8db202b01c883c58be7fad8bd"; // semisol


// program arguments
const request = "request";
const user    = "user";

void printEventsAsTree(events) {
    if( events.length == 0) {
      print("In printEventsAsTree: events length = 0");
      return;
    }

    // populate the global with display names which can be later used by Event print
    events.forEach( (x) => processKind0Event(x));

    // remove all events other than kind 1 ( posts)
    events.removeWhere( (item) => item.eventData.kind != 1 );  

    // remove bot events
    events.removeWhere( (item) => gBots.contains(item.eventData.pubkey));

    // remove duplicate events
    Set ids = {};
    events.retainWhere((x) => ids.add(x.eventData.id));

    // create tree from events
    Tree node = Tree.fromEvents(events);

    // print all the events in tree form  
    node.printTree(0, true);

    print('\n\n===================summary=================');
    //printUserInfo(events, "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245");
    //printUserInfo(events, "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d");
    //printUserInfo(events, "3235036bd0957dfb27ccda02d452d7c763be40c91a1ac082ba6983b25238388c");
    //printUserInfo(events, "ed1d0e1f743a7d19aa2dfb0162df73bacdbc699f67cc55bb91a98c35f7deac69");

    print('\nnumber of all events      : ${events.length}');
    //print("number or events of kind 0: ${gKindONames.length}");
    //print("number of bots ignored    : ${gBots.length}");
}

Future<void> main(List<String> arguments) async {
    List<Event>  events = [];
    int numEvents = 6;

    final parser = ArgParser()..addOption(request, abbr: 'r')..addOption(user, abbr:"u");
    ArgResults argResults = parser.parse(arguments);

    if( argResults[request] != null) {
      stdout.write("got argument request ${argResults[request]}");
      sendRequest("wss://nostr-pub.wellorder.net", argResults[request], events);
      Future.delayed(const Duration(milliseconds: 6000), () {
          printEventsAsTree(events);
          exit(0);      
      });
      return;
    } else {
      if( argResults[user] != null) {
        userPublickey = argResults[user];
      }
    }

    // the default in case no arguments are given is:
    // get a user's events, then from its type 3 event, gets events of its follows,
    // then get the events of user-id's mentioned in p-tags of received events
    // then display them all
    getUserEvents(defaultServerUrl, userPublickey, events, 1000);

    int numUserEvents = 0, numFeedEvents = 0, numOtherEvents = 0;

    const int numWaitSeconds = 2000;
    stdout.write('Waiting for user events to come in....');
    Future.delayed(const Duration(milliseconds: numWaitSeconds), () {
      // count user events
      events.forEach((element) { element.eventData.kind == 1? numUserEvents++: numUserEvents;});
      stdout.write(".. got ${events.length} total events\n");

      // get user's feed ( from follows by looking at kind 3 event)
      List<String> contactList = [];
      int latestContactsTime = 0;

      print("processing contact, event of kind 3");
      int latestContactIndex = -1;
      for( int i = 0; i < events.length; i++) {
        var e = events[i];
        if( e.eventData.kind == 3 && latestContactsTime < e.eventData.createdAt) {
          latestContactIndex = i;
          latestContactsTime = e.eventData.createdAt;
        }
      }

      if (latestContactIndex != -1) {
          events[latestContactIndex].printEvent(0);
          print("got latestContactIndex = $latestContactIndex");
          contactList = getContactFeed(events[latestContactIndex].eventData.contactList, events, 300);
          print("number of contacts = ${contactList.length}");
      }

      stdout.write('waiting for feed to come in.....');
      Future.delayed(const Duration(milliseconds: numWaitSeconds * 1), () {

        // count feed events
        events.forEach((element) { element.eventData.kind == 1? numFeedEvents++: numFeedEvents;});
        numFeedEvents = numFeedEvents - numUserEvents;
        stdout.write("received $numFeedEvents from the follows\n");

        // get mentioned ptags, and then get the events for those users
        List<String> pTags = getpTags(events);

        print("Total number of pTags = ${pTags.length}\n");
        getMultiUserEvents(defaultServerUrl, pTags, events, 300);
        
        print('waiting for rest of events to come in....');
        Future.delayed(const Duration(milliseconds: numWaitSeconds * 1), () {
          // count other events
          events.forEach((element) { element.eventData.kind == 1? numOtherEvents++: numOtherEvents;});
          numOtherEvents = numOtherEvents - numFeedEvents - numUserEvents;

          printEventsAsTree(events);

          print("number of user events     : $numUserEvents");
          //print("number of feed events    : $numFeedEvents");
          //print("number of other events   : $numOtherEvents");

          String authorName = getAuthorName(userPublickey);
          print("\nFinished fetching feed for user $userPublickey ($authorName), whose contact list has ${contactList.length} profiles.\n ");
          contactList.forEach((x) => stdout.write(getAuthorName(x) + ", "));
          stdout.write("\n");
          exit(0);
        });
      });
    });
}