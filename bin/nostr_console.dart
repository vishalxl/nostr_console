import 'dart:io';
import 'package:nostr_console/nostr_console_ds.dart';
import 'package:nostr_console/relays.dart';

var    userPublickey = "3235036bd0957dfb27ccda02d452d7c763be40c91a1ac082ba6983b25238388c"; // vishalxl
// var    userPublickey = "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245"; // jb55
// var    userPublickey = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"; // fiatjaf



Future<void> main() async {
  List<Event>  events = [];
  int numEvents = 6;
  getUserEvents(defaultServerUrl, userPublickey, events, numEvents);
  
  print('waiting for user events to come in');
  Future.delayed(const Duration(milliseconds: 2000), () {

    for( int i = 0; i < events.length; i++) {
      var e = events[i];
      if( e.eventData.kind == 3) {
        print('calling getfeed');
        getFeed(e.eventData.contactList, events, 20);
      }
    }

    print('waiting for feed to come in');
    Future.delayed(const Duration(milliseconds: 4000), () {
      
      print('====================all events =================');
      
      List<String> pTags = getpTags(events);
      stdout.write("Total number of pTags = ${pTags.length}\n");

      for(int i = 0; i < pTags.length; i++) {
        getUserEvents( defaultServerUrl, pTags[i], events, 10);
      }

      Future.delayed(const Duration(milliseconds: 4000), () {
        events.removeWhere( (item) => item.eventData.kind != 1 );  
        // remove duplicate events
        final ids = Set();
        events.retainWhere((x) => ids.add(x.eventData.id));

        // create tree from events
        Tree node = Tree.fromEvents(events);

        // print all the events in tree form  
        node.printTree(0, true);

        print('\nnumber of all events: ${events.length}');
        exit(0);
      });
    });
  });
}