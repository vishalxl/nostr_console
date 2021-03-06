
import 'dart:io';
import 'dart:convert';
import 'package:nostr_console/nostr_console.dart';

int    getLatestNum  = 2;

String getSubscriptionRequest(String publicKey, int numUserEvents) {
  var    strSubscription1  = '["REQ","latest",{ "authors": ["';
  var    strSubscription2  ='"], "limit": $numUserEvents  } ]';
  return strSubscription1 + publicKey + strSubscription2;
}

class Relays {
  Map<String, Future<WebSocket> > relays;

  Relays(this.relays);

  factory Relays.relay(String relay) {
    Future<WebSocket> fws = WebSocket.connect(relay);
    print('In Relay.relay: connecting to relay $relay');
    Map<String,  Future<WebSocket>> r = Map();
    r[relay] = fws;
    return Relays(r);
  }

  void connect(String relay, String publicKey, List<Event> events, int numUserEvents) {
    Future<WebSocket>? fws;
    if(relays.containsKey(relay)) {
      fws = relays[relay];
    }
    else {
      print('connecting to $relay');

      try {
        fws = WebSocket.connect(relay);
        relays[relay] = fws;
        fws.then((WebSocket ws) {
        ws.listen(
            (d) {
              print(d);
              Event e;
              try {
                e = Event.fromJson(jsonDecode(d));
                events.add(e);
                if( e.eventData.kind == 3) {
                  
                }
              } on FormatException {
                print( 'exception in fromJson for event');
              }
            },
            onError: (e) { print("error"); print(e);  },
            onDone:  () { print('in onDone'); ws.close() ; }
        );});


      } on WebSocketException {
        print('WebSocketException exception');
        return;
      } catch(e) {
        print('exception generic');
        return;
      }
    }

    print('sending request ${getSubscriptionRequest(publicKey, numUserEvents)}');
    fws?.then((WebSocket ws) { ws.add(getSubscriptionRequest(publicKey, numUserEvents)); });
  
  }

  Future<WebSocket>? getWS(String relay) {
    return relays[relay];
  }

}

Relays relays = Relays(Map());

void getFeed(List<Contact> contacts, events, numEvents) {
  for( int i = 0; i < contacts.length; i++) {
    var contact = contacts[i];
    relays.connect(contact.relay, contact.id, events, numEvents);
  }
 
  
}

void getUserEvents(serverUrl, publicKey, events, numUserEvents) {
  relays.connect(serverUrl, publicKey, events, numUserEvents);
}