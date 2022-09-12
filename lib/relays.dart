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
  int                numRequestsSent;
  Relay(this.url, this.socket, this.users, this.numReceived, this.numRequestsSent);

  void printInfo()   { 
    print("$url ${getNumSpaces(45 - url.length)}   $numReceived                   ${users.length}");
  }
}

/*
 * @class Relays Contains connections to all relays. 
 */
class Relays {
  Map<String, Relay> relays;
  Set<Event>  rEvents = {}; // current events received. can be used by others. Is cleared after consumption
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
    Relay relayObject = Relay( relayUrl, fws, [], 0, 0);
    mapRelay[relayUrl] = relayObject;
    
    return Relays(mapRelay, {}, {});
  }


  void getKindEvents(List<int> kind, String relayUrl, int limit, int sinceWhen) {
    kind.toString();
    String subscriptionId = "kind_" + kind.toString() + "_" + relayUrl.substring(6);
    String request = getKindRequest(subscriptionId, kind,  limit, sinceWhen);
   
    sendRequest(relayUrl, request);
  }
  /* 
   * @connect Connect to given relay and get all events for the given publicKey and insert the
   *          received events in the given List<Event>
   */
  void getUserEvents(String relayUrl, String publicKey, int limit, int sinceWhen) {
    for(int i = 0; i < gBots.length; i++) { // ignore bots
      if( publicKey == gBots[i]) {
        return;
      }
    }

    String subscriptionId = "single_user" + (relays[relayUrl]?.numRequestsSent??"").toString() + "_" + relayUrl.substring(6);
    if( relays.containsKey(relayUrl)) {
      List<String>? users = relays[relayUrl]?.users;
      if( users != null) { // get a user only if it has not already been requested
        // following is too restrictive casuse changed sinceWhen is not considered. TODO improve it
        for(int i = 0; i < users.length; i++) {
          if( users[i] == publicKey) {
            return;
          }
        }
        users.add(publicKey);
      }
    }
    
    String request = getUserRequest(subscriptionId, publicKey, limit, sinceWhen);
    sendRequest(relayUrl, request);
  }    

  void getMentionEvents(String relayUrl, String publicKey, int limit, int sinceWhen) {
    for(int i = 0; i < gBots.length; i++) { // ignore bots
      if( publicKey == gBots[i]) {
        return;
      }
    }

    String subscriptionId = "mention" + (relays[relayUrl]?.numRequestsSent??"").toString() + "_" + relayUrl.substring(6);
    if( relays.containsKey(relayUrl)) {
      List<String>? users = relays[relayUrl]?.users;
      if( users != null) { // get a user only if it has not already been requested
        // following is too restrictive casuse changed sinceWhen is not considered. TODO improve it
        for(int i = 0; i < users.length; i++) {
          if( users[i] == publicKey) {
            return;
          }
        }
        users.add(publicKey);
      }
    }
    
    String request = getMentionRequest(subscriptionId, publicKey, limit, sinceWhen);
    sendRequest(relayUrl, request);
  }    


  /* 
   * @connect Connect to given relay and get all events for multiple users/publicKey and insert the
   *          received events in the given List<Event>
   */
  void getMultiUserEvents(String relayUrl, List<String> publicKeys, int limit, int sinceWhen) {
    
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

    String subscriptionId = "multiple_user" + (relays[relayUrl]?.numRequestsSent??"").toString() + "_" + relayUrl.substring(6);

    String request = getMultiUserRequest( subscriptionId, reqKeys, limit, sinceWhen);
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
      relays[relay]?.numRequestsSent++;
    }
    else {
      if(gDebug !=0) print('connecting to $relay');

      try {
          IOWebSocketChannel fws2 = IOWebSocketChannel.connect(relay);
          Relay newRelay = Relay(relay, fws2, [], 0, 1);
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
                newRelay.numReceived++;

                String id = json[2]['id'] as String;
                if( uniqueIdsRecieved.contains(id)) { // rEvents is often cleared, but uniqueIdsRecieved contains everything received til now
                  return;
                } 

                e = Event.fromJson(d, relay);

                if( gDebug > 0) log.info("In listener: Event size before adding: ${rEvents.length}");
                if( rEvents.add(e) ) {
                  uniqueIdsRecieved.add(id);
                  String receivedSubscription = json[1];
                  if( gDebug > 3) e.eventData.printEventData(0, true); 
                  if( gDebug > 2) print("");

                  if( gDebug > 1) log.info("In relay listener for relay url $relay: after adding element, rEvents Size = ${rEvents.length}  numReceived = ${newRelay.numReceived} for subscription $receivedSubscription");
                  if( gDebug > 1) print("\n"); 
                } else {
                }
              } on FormatException {
                print( 'exception in fromJson for event');
                return;
              } catch(err) {
                print('exception generic $err for relay $relay');
                return;
              }                
            },
            onError: (err) { print("\n${gWarningColor}Warning: In SendRequest creating connection to $relay. Kindly check your internet connection. Or maybe only this relay is down.>"); print(gColorEndMarker); },
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

    
    if(gDebug > 0) log.info('Sending request: \n$request\n to $relay\n\n');
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

Relays relays = Relays({}, {}, {});

String getKindRequest(String subscriptionId, List<int> kind, int limit, int sinceWhen) {
  String strTime = "";
  if( sinceWhen != 0) {
    strTime = ', "since":${sinceWhen.toString()}';
  }
  var    strSubscription1  = '["REQ","$subscriptionId",{"kinds":[';
  var    strSubscription2  ='], "limit":$limit$strTime  } ]';

  String strKind = "";
  for(int i = 0; i < kind.length; i++) {
    String comma = ",";
    if( i == kind.length-1) {
      comma = "";
    }
    strKind = strKind + kind[i].toString() + comma;
  }
  String strRequest = strSubscription1 + strKind + strSubscription2;
  //print(strRequest);
  return strRequest;
}

String getUserRequest(String subscriptionId, String publicKey, int numUserEvents, int sinceWhen) {
  String strTime = "";
  if( sinceWhen != 0) {
    strTime = ', "since": ${sinceWhen.toString()}';
  }
  var    strSubscription1  = '["REQ","$subscriptionId",{ "authors": ["';
  var    strSubscription2  ='"], "limit": $numUserEvents $strTime  } ]';
  return strSubscription1 + publicKey.toLowerCase() + strSubscription2;
}


String getMentionRequest(String subscriptionId, String publicKey, int numUserEvents, int sinceWhen) {
  String strTime = "";
  if( sinceWhen != 0) {
    strTime = ', "since": ${sinceWhen.toString()}';
  }
  var    strSubscription1  = '["REQ","$subscriptionId",{ "#p": ["';
  var    strSubscription2  ='"], "limit": $numUserEvents $strTime  } ]';
  return strSubscription1 + publicKey.toLowerCase() + strSubscription2;
}

String getMultiUserRequest(String subscriptionId, List<String> publicKeys, int numUserEvents, int sinceWhen) {
  String strTime = "";
  if( sinceWhen != 0) {
    strTime = ', "since": ${sinceWhen.toString()}';
  }

  var    strSubscription1  = '["REQ","$subscriptionId",{ "authors": [';
  var    strSubscription2  ='], "limit": $numUserEvents $strTime } ]';
  String s = "";

  for(int i = 0; i < publicKeys.length; i++) {
    s += "\"${publicKeys[i].toLowerCase()}\"";
    if( i < publicKeys.length - 1) {
      s += ",";
    } 
  }
  return strSubscription1 + s + strSubscription2;
}

void getContactFeed(List<String> relayUrls, Set<String> setContacts, int numEventsToGet, int sinceWhen) {
  
  List<String> contacts = setContacts.toList();

  for( int i = 0; i < contacts.length; i += gMaxAuthorsInOneRequest) {

    // for last iteration change upper limit
    int upperLimit = (i + gMaxAuthorsInOneRequest) > contacts.length? 
                          (contacts.length - i): gMaxAuthorsInOneRequest;
    
    List<String> groupContacts = [];
    for( int j = 0; j < i + upperLimit; j++) {
      groupContacts.add(contacts[i + j]);
    }

    //print( "i = $i upperLimit = $upperLimit") ;
    relayUrls.forEach((relayUrl) {
      relays.getMultiUserEvents(relayUrl, groupContacts, numEventsToGet, sinceWhen);
    });
  
  }

  // return contact list for use by caller
  return;
}

void getUserEvents(List<String> serverUrls, String publicKey, int numUserEvents, int sinceWhen) {
  serverUrls.forEach((serverUrl) {
      relays.getUserEvents(serverUrl, publicKey, numUserEvents, sinceWhen); 
    });
}

void getMentionEvents(List<String> serverUrls, String publicKey, int numUserEvents, int sinceWhen) {
  serverUrls.forEach((serverUrl) {
      relays.getMentionEvents(serverUrl, publicKey, numUserEvents, sinceWhen); 
    });
}


getKindEvents(List<int> kind, List<String> serverUrls, int limit, int sinceWhen) {
  serverUrls.forEach((serverUrl) {
      relays.getKindEvents(kind, serverUrl, limit, sinceWhen); 
    });
}

void getMultiUserEvents(List<String> serverUrls, List<String> publicKeys, int numUserEvents, int sinceWhen) {
  if( gDebug > 0) print("Sending multi user request for ${publicKeys.length} users");
  
  for(var serverUrl in serverUrls) {
    for( int i = 0; i < publicKeys.length; i+= gMaxAuthorsInOneRequest) {
      int getUserRequests = gMaxAuthorsInOneRequest;
      if( publicKeys.length - i <= gMaxAuthorsInOneRequest) {
        getUserRequests = publicKeys.length - i;
      }
      //print("    sending request form $i to ${i + getUserRequests} ");
      List<String> partialList = publicKeys.sublist(i, i + getUserRequests);
      relays.getMultiUserEvents(serverUrl, partialList, numUserEvents, sinceWhen);
    }
  }
}

//
void sendEventsRequest(List<String> serverUrls, List<String> eventIds) {
  if( eventIds.length == 0) 
    return;

  String eventIdsStr = "";
  for(int i = 0; i < eventIds.length; i++) {
    String comma = ",";
    if( i == 0) 
      comma = "";
    eventIdsStr =  '$eventIdsStr$comma"${eventIds[i]}"';
  }

  String getEventRequest = '["REQ","event_${eventIds.length}",{"ids":[$eventIdsStr]}]';
  if( gDebug > 0) log.info("sending $getEventRequest");
  for(int i = 0; i < serverUrls.length; i++) {
    relays.sendRequest(serverUrls[i], getEventRequest);
  }

/*    Future<void> foo() async {
      await Future.delayed(Duration(milliseconds: 500));
      return;
    }
*/

}

void sendRequest(List<String> serverUrls, request) {
  for(int i = 0; i < serverUrls.length; i++) {
    relays.sendRequest(serverUrls[i], request);
  }
}

Set<Event> getRecievedEvents() {
  return relays.rEvents;
}

void clearEvents() {
  relays.rEvents.clear();
  if( gDebug > 0) print("clearEvents(): returning");
}

void setRelaysIntialEvents(Set<Event> eventsFromFile) {
  eventsFromFile.forEach((element) {relays.uniqueIdsRecieved.add(element.eventData.id);});
  relays.rEvents = eventsFromFile;
}

