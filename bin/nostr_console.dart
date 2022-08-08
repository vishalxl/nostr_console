import 'dart:io';
import 'package:nostr_console/nostr_console_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:args/args.dart';


var    userPublickey = "3235036bd0957dfb27ccda02d452d7c763be40c91a1ac082ba6983b25238388c"; // vishalxl
//var    userPublickey = "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245"; // jb55
//var    userPublickey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"; // fiatjaf

// program arguments
const request = "request";

void printEventsAsTree(events) {
    if( events.length == 0) {
      print("In printEventsAsTree: events length = 0");
      return;
    }

    // populate the global with display names which can be later used by Event print
    events.forEach( (x) => getNames(x));

    // remove all events other than kind 1 ( posts)
    events.removeWhere( (item) => item.eventData.kind != 1 );  

    // remove duplicate events
    Set ids = {};
    events.retainWhere((x) => ids.add(x.eventData.id));

    // create tree from events
    Tree node = Tree.fromEvents(events);

    // print all the events in tree form  
    node.printTree(0, true);

    print('\n\n===================summary=================');
    //printUserInfo(events, "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245");

    print('\nnumber of all events      : ${events.length}');
    print("number or events of kind 0: ${gKindONames.length}");
}

Future<void> main(List<String> arguments) async {
    List<Event>  events = [];
    int numEvents = 6;

    final parser = ArgParser()..addOption(request, abbr: 'r');
    ArgResults argResults = parser.parse(arguments);

    if( argResults[request] != null) {
      stdout.write("got argument request ${argResults[request]}");
      sendRequest("wss://nostr-pub.wellorder.net", argResults[request], events);
      Future.delayed(const Duration(milliseconds: 6000), () {
          printEventsAsTree(events);
          exit(0);      
      });
      return;
    }

    // the default in case no arguments are given is:
    // get a user's events, then from its type 3 event, gets events of its follows,
    // then get the events of user-id's mentioned in p-tags of received events
    // then display them all
    getUserEvents(defaultServerUrl, userPublickey, events, 300);

    int numUserEvents = 0, numFeedEvents = 0, numOtherEvents = 0;

    const int numWaitSeconds = 3000;
    print('waiting for user events to come in....');
    Future.delayed(const Duration(milliseconds: numWaitSeconds * 2), () {
      // count user events
      events.forEach((element) { element.eventData.kind == 1? numUserEvents++: numUserEvents;});

      // get user's feed ( from follows by looking at kind 3 event)
      for( int i = 0; i < events.length; i++) {
        var e = events[i];
        if( e.eventData.kind == 3) {
          print('calling getfeed');
          getFeed(e.eventData.contactList, events, 300);
        }
      }

      print('waiting for feed to come in.....');
      Future.delayed(const Duration(milliseconds: numWaitSeconds * 2), () {
        // count feed events
        events.forEach((element) { element.eventData.kind == 1? numFeedEvents++: numFeedEvents;});
        numFeedEvents = numFeedEvents - numUserEvents;

        // get mentioned ptags, and then get the events for those users
        List<String> pTags = getpTags(events);
        print("Total number of pTags = ${pTags.length}\n");

        for(int i = 0; i < pTags.length; i++) {
          getUserEvents( defaultServerUrl, pTags[i], events, 300);
        }
        
        print('waiting for rest of events to come in....');
        Future.delayed(const Duration(milliseconds: numWaitSeconds), () {
          // count other events
          events.forEach((element) { element.eventData.kind == 1? numOtherEvents++: numOtherEvents;});
          numOtherEvents = numOtherEvents - numFeedEvents - numUserEvents;

          printEventsAsTree(events);
          print("number of user events    : $numUserEvents");
          print("number of feed events    : $numFeedEvents");
          print("number of other events   : $numOtherEvents");
          exit(0);
        });
      });
    });
}