import 'dart:io';

import 'dart:convert';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/settings.dart';
import 'package:nostr_console/utils.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/src/exception.dart';

class Relay { 
  String             url;
  IOWebSocketChannel socket;
  Set<String>       users;         // is used so that duplicate requests aren't sent for same user for this same relay; unused for now
  int                numReceived;
  int                numRequestsSent;
  Relay(this.url, this.socket, this.users, this.numReceived, this.numRequestsSent);

  void close() {
    socket.sink.close().onError((error, stackTrace) => null);
  }

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

  void closeAll() {
    relays.forEach((url, relay) {
      relay.close();
    });

    //relays.clear();
  }

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
    Relay relayObject = Relay( relayUrl, fws, {}, 0, 0);
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
      Set<String>? users = relays[relayUrl]?.users;
      if( users != null) { // get a user only if it has not already been requested
        // following is too restrictive casuse changed sinceWhen is not considered. TODO improve it
        bool alreadyRecevied = false;
        users.forEach((user) { 
          if( user == publicKey) {
            alreadyRecevied = true;
          }
        });

        if( alreadyRecevied)
          return;
    
        users.add(publicKey);
      }
    }
    
    String request = getUserRequest(subscriptionId, publicKey, limit, sinceWhen);
    //print("In relay: getKind events: request = $request");
    sendRequest(relayUrl, request);
  }    

  void getMentionEvents(String relayUrl, Set<String> ids, int limit, int sinceWhen, String tagToGet) {
    for(int i = 0; i < gBots.length; i++) { // ignore bots
      if( ids == gBots[i]) {
        return;
      }
    }

    String subscriptionId = "mention" + (relays[relayUrl]?.numRequestsSent??"").toString() + "_" + relayUrl.substring(6);
    
    String request = getMentionRequest(subscriptionId, ids, limit, sinceWhen, tagToGet);
    sendRequest(relayUrl, request);
  }    

  void getIdAndMentionEvents(String relayUrl, Set<String> ids, int limit, int idSinceWhen, int mentionSinceWhen, String tagToGet, String idType) {

    String subscriptionId = "id_mention_tag" + (relays[relayUrl]?.numRequestsSent??"").toString() + "_" + relayUrl.substring(6);
    String request = getIdAndMentionRequest(subscriptionId, ids, limit, idSinceWhen, mentionSinceWhen, tagToGet, idType);
    sendRequest(relayUrl, request);
  }    


  /* 
   * @connect Connect to given relay and get all events for multiple users/publicKey and insert the
   *          received events in the given List<Event>
   */
  void getMultiUserEvents(String relayUrl, List<String> publicKeys, int limit, int sinceWhen, [Set<int>? kind = null]) {
    Set<String> setPublicKeys = publicKeys.toSet();

    if( relays.containsKey(relayUrl)) {
      Set<String>? users = relays[relayUrl]?.users;
      if( users != null) {
        relays[relayUrl]?.users = users.union(setPublicKeys);

      }
    }

    String subscriptionId = "multiple_user" + (relays[relayUrl]?.numRequestsSent??"").toString() + "_" + relayUrl.substring(6);
    String request = getMultiUserRequest( subscriptionId, setPublicKeys, limit, sinceWhen, kind);
    sendRequest(relayUrl, request);
  }    

  /*
   * Send the given string to the given relay. Is used to send both requests, and to send evnets. 
   */
  void sendRequest(String relayUrl, String request) async {
    if(relayUrl == "" ) {
      if( gDebug != 0) print ("Invalid or empty relay given");
      return;
    }

    if( gDebug > 0) print ("\nIn relay.sendRequest for relay $relayUrl");

    IOWebSocketChannel?  fws;
    if(relays.containsKey(relayUrl)) {
      
      fws = relays[relayUrl]?.socket;
      relays[relayUrl]?.numRequestsSent++;
    }
    else {
      if(gDebug !=0) print('connecting to $relayUrl');

      try {
          IOWebSocketChannel fws2 = IOWebSocketChannel.connect(relayUrl);

        try {
          await fws2.ready;
        } catch (e) {
          // handle exception here
          //print("Error: Failed to connect to relay $relayUrl . Got exception = |${e.toString()}|");
          return;
        }          
          
          Relay newRelay = Relay(relayUrl, fws2, {}, 0, 1);
          relays[relayUrl] = newRelay;
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

                e = Event.fromJson(d, relayUrl);

                if( rEvents.add(e) ) {
                  uniqueIdsRecieved.add(id);
                } else {
                }
              } on FormatException {
                return;
              } catch(err) {
                return;
              }                
            }, 
            onError: (err) { if(gDebug > 0) printWarning("Warning: Error in creating connection to $relayUrl. Kindly check your internet connection. Or maybe only this relay is down."); },
            onDone:  () { if( gDebug > 0) print('Info: In onDone'); }
          );
      } on WebSocketException {
        print('WebSocketException exception for relay $relayUrl');
        return;
      } on WebSocketChannelException {
        print('WebSocketChannelException exception for relay $relayUrl');
        return; // is presently not used/called
      }
      on Exception catch(ex) {
        printWarning("Invalid event\n");
      }
      
      catch(err) {
        if( gDebug >= 0) printWarning('exception generic $err for relay $relayUrl\n');
        return;
      }
    }

    if(gDebug > 0) log.info('Sending request: \n$request\n to $relayUrl\n\n');
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

void getContactFeed(Set<String> relayUrls, Set<String> setContacts, int numEventsToGet, int sinceWhen) {
  
  List<String> contacts = setContacts.toList();
  for( int i = 0; i < contacts.length; i += gMaxAuthorsInOneRequest) {

    // for last iteration change upper limit
    int upperLimit = (i + gMaxAuthorsInOneRequest) > contacts.length? 
                          (contacts.length - i): gMaxAuthorsInOneRequest;
    
    List<String> groupContacts = [];
    for( int j = 0; j < upperLimit; j++) {
      groupContacts.add(contacts[i + j]);
    }

    relayUrls.forEach((relayUrl) {
      relays.getMultiUserEvents(relayUrl, groupContacts, numEventsToGet, sinceWhen);
    });
  
  }

  // return contact list for use by caller
  return;
}

void getUserEvents(Set<String> serverUrls, String publicKey, int numUserEvents, int sinceWhen) {
  serverUrls.forEach((serverUrl) {
      relays.getUserEvents(serverUrl, publicKey, numUserEvents, sinceWhen); 
    });
}

void getMentionEvents(Set<String> serverUrls, Set<String> ids, int numUserEvents, int sinceWhen, String tagToGet) {
  serverUrls.forEach((serverUrl) {
      relays.getMentionEvents(serverUrl, ids, numUserEvents, sinceWhen, tagToGet); 
    });
}

void getIdAndMentionEvents(Set<String> serverUrls, Set<String> ids, int numUserEvents, int idSinceWhen, int mentionSinceWhen, String tagToGet, String idType) {
  serverUrls.forEach((serverUrl) {
      relays.getIdAndMentionEvents(serverUrl, ids, numUserEvents, idSinceWhen, mentionSinceWhen, tagToGet, idType); 
    });
}


getKindEvents(List<int> kind, Set<String> serverUrls, int limit, int sinceWhen) {
  serverUrls.forEach((serverUrl) {
      relays.getKindEvents(kind, serverUrl, limit, sinceWhen); 
    });
}

void getMultiUserEvents(Set<String> serverUrls, Set<String> setPublicKeys, int numUserEvents, int sinceWhen, [Set<int>? kind]) {
  List<String> publicKeys = setPublicKeys.toList();
  if( gDebug > 0) print("Sending multi user request for ${publicKeys.length} users");
  
  for(var serverUrl in serverUrls) {
    for( int i = 0; i < publicKeys.length; i+= gMaxAuthorsInOneRequest) {
      int getUserRequests = gMaxAuthorsInOneRequest;
      if( publicKeys.length - i <= gMaxAuthorsInOneRequest) {
        getUserRequests = publicKeys.length - i;
      }
      List<String> partialList = publicKeys.sublist(i, i + getUserRequests);
      relays.getMultiUserEvents(serverUrl, partialList, numUserEvents, sinceWhen, kind);
    }
  }
}

// send request for specific events whose id's are passed as list eventIds
void sendEventsRequest(Set<String> serverUrls, Set<String> eventIds) {
  if( eventIds.length == 0) 
    return;

  String eventIdsStr = getCommaSeparatedQuotedStrs(eventIds);;

  String getEventRequest = '["REQ","event_${eventIds.length}",{"ids":[$eventIdsStr]}]';
  if( gDebug > 0) log.info("sending $getEventRequest");

  serverUrls.forEach((url) {
    relays.sendRequest(url, getEventRequest);
  });
}

void sendRequest(Set<String> serverUrls, request) {
  serverUrls.forEach((url) { 
    relays.sendRequest(url, request);
  });
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

