
import 'dart:io';
import 'package:nostr_console/nostr_console.dart';
import 'package:nostr_console/relays.dart';

var    userPublickey = "3235036bd0957dfb27ccda02d452d7c763be40c91a1ac082ba6983b25238388c";



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
        getFeed(e.eventData.contactList, events, 5);
      }
    }


    print('waiting for feed to come in');
    Future.delayed(const Duration(milliseconds: 4000), () {
      events.sort(ascendingTime);
      events.removeWhere( (item) => item.eventData.kind != 1 );
      print('====================all events =================');
      
      //printEvents(events);

      Tree node = Tree.fromEvents(events);
      node.printTree(0, true);
      print('\nnumber of all events: ${events.length}');


      exit(0);

    });



  });
}
