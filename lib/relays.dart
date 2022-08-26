import 'dart:io';
import 'dart:convert';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/settings.dart';
import 'package:web_socket_channel/io.dart';


class Relay { 
  String             url;
  IOWebSocketChannel socket;
  List<String>       users;         // is used so that duplicate requests aren't sent for same user for this same relay
  int                numReceived;
  Relay(this.url, this.socket, this.users, this.numReceived);

  void printInfo()   { 
    //print("In Relay: printInfo"); 
    print("$url ${getNumSpaces(45 - url.length)}   $numReceived                   ${users.length}");
  }
}

/*
 * @class Relays Contains connections to all relays. 
 */
class Relays {
  Map<String, Relay> relays;
  List<Event>  rEvents = []; // current events received. can be used by others. Is cleared after consumption
  Set<String>  uniqueIdsRecieved = {} ; // id of events received. only for internal usage, so that duplicate events are rejected
  Relays(this.relays, this.rEvents, this.uniqueIdsRecieved);

  void printInfo()  {
    printUnderlined("Server connection info");
    print("     Server Url                    Num events received:   Num users requested");
    for( var key in relays.keys) {
     
     relays[key]?.printInfo();
    }
  }

  factory Relays.relay(String relayUrl) {
    IOWebSocketChannel  fws = IOWebSocketChannel.connect(relayUrl);
    print('In Relay.relay: connecting to relay $relayUrl');
    Map<String,  Relay> mapRelay = {};
    Relay relayObject = Relay( relayUrl, fws, [], 0);
    mapRelay[relayUrl] = relayObject;
    
    return Relays(mapRelay, [], {});
  }

  /* 
   * @connect Connect to given relay and get all events for the given publicKey and insert the
   *          received events in the given List<Event>
   */
  void getUserEvents(String relayUrl, String publicKey, int numEventsToGet, int sinceWhen) {
    for(int i = 0; i < gBots.length; i++) {
      if( publicKey == gBots[i]) {
        //print("In gerUserEvents: ignoring bot: $publicKey");
        return;
      }
    }

    if( relays.containsKey(relayUrl)) {
      List<String>? users = relays[relayUrl]?.users;
      if( users != null) {
        // following is too restrictive casuse changed sinceWhen is not considered. TODO improve it
        for(int i = 0; i < users.length; i++) {
          if( users[i] == publicKey) {
            return;
          }
        }
        users.add(publicKey);
      }
    }
    String request = getUserRequest(publicKey, numEventsToGet, sinceWhen);
    sendRequest(relayUrl, request);
  }    

  /* 
   * @connect Connect to given relay and get all events for multiple users/publicKey and insert the
   *          received events in the given List<Event>
   */
  void getMultiUserEvents(String relayUrl, List<String> publicKeys, int numEventsToGet) {
    
    List<String> reqKeys = [];
    if( relays.containsKey(relayUrl)) {
      List<String>? users = relays[relayUrl]?.users;
      if( users != null) {
        // following is too restrictive. TODO improve it
        for(int i = 0; i < publicKeys.length; i++) {
          if( users.any( (u) => u == publicKeys[i])) {
            continue;
          }
          if( gBots.any( (bot) => bot == publicKeys[i] )) {
            continue;
          }
          users.add(publicKeys[i]);
          reqKeys.add(publicKeys[i]);
        }
      }
    } // if relay exists and has a user list

    String request = getMultiUserRequest(reqKeys, numEventsToGet);
    sendRequest(relayUrl, request);
  }    

  /*
   * Send the given string to the given relay. Is used to send both requests, and to send evnets. 
   */
  void sendRequest(String relay, String request) {
    if(relay == "" ) {
      if( gDebug != 0) print ("Invalid or empty relay given");
      return;
    }

    if( gDebug > 0) print ("\nIn relay.sendRequest for relay $relay");

    IOWebSocketChannel?  fws;
    if(relays.containsKey(relay)) {
      fws = relays[relay]?.socket;
    }
    else {
      if(gDebug !=0) print('connecting to $relay');

      try {
          IOWebSocketChannel fws2 = IOWebSocketChannel.connect(relay);
          Relay newRelay = Relay(relay, fws2, [], 0);
          relays[relay] = newRelay;
          fws = fws2;
          fws2.stream.listen(
                (d) {
                  Event e;
                  try {
                    dynamic json = jsonDecode(d);
                    if( json.length < 3) {
                      return;
                    }
                    String id = json[2]['id'] as String;
                    if( uniqueIdsRecieved.contains(id)) {
                      if( gDebug > 0) print("In relay: received duplicate event id : $id");
                      return;
                    } else {
                      uniqueIdsRecieved.add(id);
                    }

                    e = Event.fromJson(d, relay);
                    if(gDebug >= 2) print("adding event to list");
                    
                    rEvents.add(e);
                    newRelay.numReceived++;
                  } on FormatException {
                    print( 'exception in fromJson for event');
                    return;
                  } catch(err) {
                    print('exception generic $err for relay $relay');
                    return;
                  }                
                },
                onError: (err) { print("\n${warningColor}Warning: In SendRequest creating connection onError. Kindly check your internet connection or change the relay by command line --relay=<relay wss url>"); print(colorEndMarker); },
                onDone:  () { if( gDebug != 0) print('Info: In onDone'); }
          );
      } on WebSocketException {
        print('WebSocketException exception for relay $relay');
        return;
      } catch(err) {
        print('exception generic $err for relay $relay');
        return;
      }
    }

    if(gDebug > 0) print('\nSending request: \n$request\n to $relay\n\n');
    fws?.sink.add(request);
  }


  IOWebSocketChannel? getWS(String relay) {
    return relays[relay]?.socket;
  }

  void printStatus() {
    print("In Relays::printStatus. Number of relays = ${relays.length}");
    relays.forEach((key, value) {
      print("for relay: $key");
      print("$value\n");
      String? reason = value.socket.closeReason;
      print( reason??"reason not found");
    });
  }
}

Relays relays = Relays({}, [], {});

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

List<String> getContactFeed(List<String> relayUrls, List<Contact> contacts, numEventsToGet) {
  
  // maps from relay url to list of users that it supplies events for
  Map<String, List<String> > mContacts = {};

  List<String> contactList = [];

  // creat the mapping between relay and its hosted users
  for( int i = 0; i < contacts.length; i++) {
    if( mContacts.containsKey(contacts[i].relay) ) {
      mContacts[contacts[i].relay]?.add(contacts[i].id);
    } else {
      mContacts[contacts[i].relay] = [contacts[i].id];
    }
    contactList.add(contacts[i].id);
  }

  // send request for the users events to the relays
  mContacts.forEach((key, value) { 
    relays.getMultiUserEvents(key, value, numEventsToGet);
    
    relayUrls.forEach((relayUrl) {
      relays.getMultiUserEvents(relayUrl, value, numEventsToGet);
    });

  });

  // return contact list for use by caller
  return contactList;  
}

void getUserEvents(List<String> serverUrls, publicKey, numUserEvents, sinceWhen) {
  serverUrls.forEach((serverUrl) {
      relays.getUserEvents(serverUrl, publicKey, numUserEvents, sinceWhen); 
    });
}

void getMultiUserEvents(serverUrl, List<String> publicKeys, numUserEvents) {
  if( gDebug > 0) print("Sending multi user request for ${publicKeys.length} users");
  const int numMaxUserRequests = 15;
  for( int i = 0; i < publicKeys.length; i+= numMaxUserRequests) {
    int getUserRequests = numMaxUserRequests;
    if( publicKeys.length - i <= numMaxUserRequests) {
      getUserRequests = publicKeys.length - i;
    }
    //print("    sending request form $i to ${i + getUserRequests} ");
    List<String> partialList = publicKeys.sublist(i, i + getUserRequests);
    relays.getMultiUserEvents(serverUrl, partialList, numUserEvents);
  }
}

void sendRequest(List<String> serverUrls, request) {
  for(int i = 0; i < serverUrls.length; i++) {
    relays.sendRequest(serverUrls[i], request);
  }
}

List<Event> getRecievedEvents() {
  return relays.rEvents;
}

void clearEvents() {
  relays.rEvents = [];
  if( gDebug > 0) print("clearEvents(): returning");
}

void setRelaysIntialEvents(eventsFromFile) {
  relays.rEvents = eventsFromFile;
}

