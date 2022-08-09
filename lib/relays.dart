import 'dart:io';
import 'package:nostr_console/nostr_console_ds.dart';
import 'package:web_socket_channel/io.dart';

String getUserRequest(String publicKey, int numUserEvents) {
  var    strSubscription1  = '["REQ","latest",{ "authors": ["';
  var    strSubscription2  ='"], "limit": $numUserEvents  } ]';
  return strSubscription1 + publicKey + strSubscription2;
}


String getMultiUserRequest(List<String> publicKeys, int numUserEvents) {
  var    strSubscription1  = '["REQ","latest",{ "authors": [';
  var    strSubscription2  ='], "limit": $numUserEvents  } ]';
  String s = "";

  for(int i = 0; i < publicKeys.length; i++) {
    s += "\"${publicKeys[i]}\"";
    if( i < publicKeys.length - 1) {
      s += ",";
    } 
  }

  return strSubscription1 + s + strSubscription2;
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
  void getUserEvents(String relay, String publicKey, List<Event> events, int numEventsToGet) {

    for(int i = 0; i < gBots.length; i++) {
      if( publicKey == gBots[i]) {
        print("In gerUserEvents: ignoring bot: $publicKey");
        return;
      }
    }

    // following is too restrictive. TODO improve it
    for(int i = 0; i < users.length; i++) {
      if( users[i] == publicKey) {
        return;
      }
    }
    users.add(publicKey);
    String request = getUserRequest(publicKey, numEventsToGet);
    sendRequest(relay, request, events);
  }    

  /* 
   * @connect Connect to given relay and get all events for multiple users/publicKey and insert the
   *          received events in the given List<Event>
   */
  void getMultiUserEvents(String relay, List<String> publicKeys, List<Event> events, int numEventsToGet) {
    
    List<String> reqKeys = [];

    // following is too restrictive. TODO improve it
    for(int i = 0; i < publicKeys.length; i++) {
      if( users.any( (u) => u == publicKeys[i])) {
        continue;
      }

      if( gBots.any( (bot) => bot == publicKeys[i] )) {
        print("In getMultiUserEvents: ignoring a bot");
        continue;
      }

      users.add(publicKeys[i]);
      reqKeys.add(publicKeys[i]);

    }

    String request = getMultiUserRequest(reqKeys, numEventsToGet);
    sendRequest(relay, request, events);
  }    

  void sendRequest(String relay, String request, List<Event> events) {

    IOWebSocketChannel?  fws;
    if(relays.containsKey(relay)) {
      fws = relays[relay];
    }
    else {
      print('\nconnecting to $relay');

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

    print('sending request: $request to $relay\n');
    fws?.sink.add(request);
  }

  IOWebSocketChannel? getWS(String relay) {
    return relays[relay];
  }

}

Relays relays = Relays(Map(), []);

void getContactFeed(List<Contact> contacts, events, numEventsToGet) {
  Map<String, List<String> > mContacts = {};

  for( int i = 0; i < contacts.length; i++) {
    if( mContacts.containsKey(contacts[i].relay) ) {
      mContacts[contacts[i].relay]?.add(contacts[i].id);
    } else {
      mContacts[contacts[i].relay] = [contacts[i].id];
    }
  }

  mContacts.forEach((key, value) { relays.getMultiUserEvents(key, value, events, numEventsToGet);})  ;
}

void getUserEvents(serverUrl, publicKey, events, numUserEvents) {
  relays.getUserEvents(serverUrl, publicKey, events, numUserEvents);
}

void getMultiUserEvents(serverUrl, publicKeys, events, numUserEvents) {
  relays.getMultiUserEvents(serverUrl, publicKeys, events, numUserEvents);
}


void sendRequest(serverUrl, request, events) {
  relays.sendRequest(serverUrl, request, events);
}