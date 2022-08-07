
import 'dart:io';
import 'package:nostr_console/nostr_console_ds.dart';

import 'package:web_socket_channel/io.dart';

String getSubscriptionRequest(String publicKey, int numUserEvents) {
  var    strSubscription1  = '["REQ","latest",{ "authors": ["';
  var    strSubscription2  ='"], "limit": $numUserEvents  } ]';
  return strSubscription1 + publicKey + strSubscription2;
}

/*
 * @class Relays Contains connections to all relays. 
 */
class Relays {
  Map<String, IOWebSocketChannel > relays;
  List<String> users; // is used to that duplicate requests aren't sent for same user

  Relays(this.relays, this.users);

  factory Relays.relay(String relay) {
    IOWebSocketChannel  fws = IOWebSocketChannel.connect(relay);
    print('In Relay.relay: connecting to relay $relay');
    Map<String,  IOWebSocketChannel> r = Map();
    r[relay] = fws;
    return Relays(r, []);
  }

  /* 
   * @connect Connect to given relay and get all events for the given publicKey and insert the
   *          received events in the given List<Event>
   */
  void gerUserEvents(String relay, String publicKey, List<Event> events, int numEventsToGet) {

    // following is too restrictive. TODO improve it
    for(int i = 0; i < users.length; i++) {
      if( users[i] == publicKey) {
        return;
      }
    }
    users.add(publicKey);
    String request = getSubscriptionRequest(publicKey, numEventsToGet);
    sendRequest(relay, request, events);
  }    

  void sendRequest(String relay, String request, List<Event> events) {

    IOWebSocketChannel?  fws;
    if(relays.containsKey(relay)) {
      fws = relays[relay];
    }
    else {
      print('connecting to $relay');

      try {
        fws = IOWebSocketChannel.connect(relay);
        relays[relay] = fws;
        fws.stream.listen(
              (d) {
                Event e;
                try {
                  e = Event.fromJson(d, relay);
                  events.add(e);
                } on FormatException {
                  print( 'exception in fromJson for event');
                }
              },
              onError: (e) { print("error"); print(e);  },
              onDone:  () { print('in onDone'); }
        );
      } on WebSocketException {
        print('WebSocketException exception');
        return;
      } catch(e) {
        print('exception generic $e');
        return;
      }
    }

    print('sending request: $request to $relay');
    fws?.sink.add(request);
  }

  IOWebSocketChannel? getWS(String relay) {
    return relays[relay];
  }

}

Relays relays = Relays(Map(), []);

void getFeed(List<Contact> contacts, events, numEventsToGet) {
  for( int i = 0; i < contacts.length; i++) {
    var contact = contacts[i];
    relays.gerUserEvents(contact.relay, contact.id, events, numEventsToGet);
  }  
}

void getUserEvents(serverUrl, publicKey, events, numUserEvents) {
  relays.gerUserEvents(serverUrl, publicKey, events, numUserEvents);
}

void sendRequest(serverUrl, request, events) {
  relays.sendRequest(serverUrl, request, events);
}