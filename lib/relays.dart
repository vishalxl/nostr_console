import 'dart:io';
import 'package:nostr_console/nostr_console_ds.dart';
import 'package:web_socket_channel/io.dart';

String getUserRequest(String publicKey, int numUserEvents, int sinceWhen) {
  String strTime = "";
  if( sinceWhen != 0) {
    strTime = ', "since": ${sinceWhen.toString()}';
  }


  var    strSubscription1  = '["REQ","single_user",{ "authors": ["';
  var    strSubscription2  ='"], "limit": $numUserEvents $strTime  } ]';
  return strSubscription1 + publicKey + strSubscription2;
}


String getMultiUserRequest(List<String> publicKeys, int numUserEvents) {
  var    strSubscription1  = '["REQ","multiple_user",{ "authors": [';
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
  List<String> users; // is used so that duplicate requests aren't sent for same user
  List<Event>  rEvents = [];

  Relays(this.relays, this.users, this.rEvents);

  factory Relays.relay(String relay) {
    IOWebSocketChannel  fws = IOWebSocketChannel.connect(relay);
    print('In Relay.relay: connecting to relay $relay');
    Map<String,  IOWebSocketChannel> r = {};
    r[relay] = fws;
    return Relays(r, [], []);
  }

  /* 
   * @connect Connect to given relay and get all events for the given publicKey and insert the
   *          received events in the given List<Event>
   */
  void getUserEvents(String relay, String publicKey, int numEventsToGet, int sinceWhen) {

    for(int i = 0; i < gBots.length; i++) {
      if( publicKey == gBots[i]) {
        //print("In gerUserEvents: ignoring bot: $publicKey");
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
    String request = getUserRequest(publicKey, numEventsToGet, sinceWhen);
    sendRequest(relay, request);
  }    

  /* 
   * @connect Connect to given relay and get all events for multiple users/publicKey and insert the
   *          received events in the given List<Event>
   */
  void getMultiUserEvents(String relay, List<String> publicKeys, int numEventsToGet) {
    
    List<String> reqKeys = [];

    // following is too restrictive. TODO improve it
    for(int i = 0; i < publicKeys.length; i++) {
      if( users.any( (u) => u == publicKeys[i])) {
        continue;
      }

      if( gBots.any( (bot) => bot == publicKeys[i] )) {
        //print("In getMultiUserEvents: ignoring a bot");
        continue;
      }

      users.add(publicKeys[i]);
      reqKeys.add(publicKeys[i]);

    }

    String request = getMultiUserRequest(reqKeys, numEventsToGet);
    sendRequest(relay, request);
  }    

  void sendRequest(String relay, String request) {

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
                  if(gDebug != 0) print("adding event to list");
                  rEvents.add(e);
                } on FormatException {
                  print( 'exception in fromJson for event');
                }
              },
              onError: (e) { print("in onError"); print(e);  },
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

    //print('sending request: $request to $relay\n');
    fws?.sink.add(request);
  }

  void sendMessage(String message, String relay) {
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
              (d) {}, //
              onError: (e) { print("in onError"); print(e);  },
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

    print('sending message: $message to $relay\n');
    fws?.sink.add(message);

  }

  IOWebSocketChannel? getWS(String relay) {
    return relays[relay];
  }

  void printStatus() {
    print("In Relays::printStatus. Number of relays = ${relays.length}");
    relays.forEach((key, value) {
      print("for relay: $key");
      print("$value\n");


      String? reason = value.closeReason;
      print( reason??"reason not found");
    });
  }
}

Relays relays = Relays({}, [], []);

List<String> getContactFeed(List<Contact> contacts, numEventsToGet) {
  Map<String, List<String> > mContacts = {};
  List<String> contactList = [];
  for( int i = 0; i < contacts.length; i++) {
    if( mContacts.containsKey(contacts[i].relay) ) {
      mContacts[contacts[i].relay]?.add(contacts[i].id);
    } else {
      mContacts[contacts[i].relay] = [contacts[i].id];
    }
    /*if( contacts[i].id == "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245") {
      print("In getContactFeed: sending request for jb55 32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245");
    }*/
    contactList.add(contacts[i].id);
  }

  mContacts.forEach((key, value) { relays.getMultiUserEvents(key, value, numEventsToGet);})  ;
  return contactList;  
}

void getUserEvents(serverUrl, publicKey, numUserEvents, sinceWhen) {
  print("in getUserEvents");
  relays.getUserEvents(serverUrl, publicKey, numUserEvents, sinceWhen);
}

void getMultiUserEvents(serverUrl, publicKeys, numUserEvents) {
  relays.getMultiUserEvents(serverUrl, publicKeys, numUserEvents);
}


void sendRequest(serverUrl, request) {
  relays.sendRequest(serverUrl, request);
}

List<Event> getRecievedEvents() {
  return relays.rEvents;
}

void clearEvents() {
  relays.rEvents = [];
}