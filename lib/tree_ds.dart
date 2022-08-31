import 'dart:io';
import 'dart:convert';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/settings.dart';

typedef fTreeSelector = bool Function(Tree a);

bool selectAll(Tree t) {
  return true;
}


/***********************************************************************************************************************************/
/*  
 * The actual tree holds only kind 1 events, or only posts
 * This super-tree class holds other events too in its map, and in its chatRooms structure
 */
class Tree {
  Event             e;                   // is dummy for very top level tree. Holds an event otherwise.
  List<Tree>        children;            // only has kind 1 events
  Map<String, Tree> allChildEventsMap;   // has events of kind typesInEventMap
  List<String>      eventsWithoutParent;
  bool              whetherTopMost;
  Map<String, ChatRoom> chatRooms = {};
  Set<String>       eventsNotReadFromFile;
  Tree(this.e, this.children, this.allChildEventsMap, this.eventsWithoutParent, this.whetherTopMost, this.chatRooms, this.eventsNotReadFromFile);

  static const Set<int>   typesInEventMap = {0, 1, 3, 7, 40, 42}; // 0 meta, 1 post, 3 follows list, 7 reactions

  static void handleChannelEvents( Map<String, ChatRoom> rooms, Map<String, Tree> tempChildEventsMap, Event ce) {
      String eId = ce.eventData.id;
      int    eKind = ce.eventData.kind;

      switch(eKind) {
      case 42:
      {
        //numKind42Events++;
        String chatRoomId = ce.eventData.getChatRoomId();
        if( chatRoomId != "") {
          if( rooms.containsKey(chatRoomId)) {
            //if( gDebug > 0) print("Adding new message $key to a chat room $chatRoomId. ");
            addMessageToChannel(chatRoomId, eId, tempChildEventsMap, rooms);
          } else {
            List<String> temp = [];
            temp.add(eId);
            ChatRoom room = ChatRoom(chatRoomId, "", "", "", temp);
            rooms[chatRoomId] = room;
            //if( gDebug > 0) print("Added new chat room object $chatRoomId and added message to it. ");
          }
        } else {
          //if( gDebug > 0) print("Could not get chat room id for event $eId, its original json: ");
        }
      }
      break;
      case 40:
       {
        //numKind40Events++;
        String chatRoomId = eId;
        try {
          dynamic json = jsonDecode(ce.eventData.content);
          if( rooms.containsKey(chatRoomId)) {
            if( rooms[chatRoomId]?.name == "") {
              //if( gDebug > 0) print('Added room name = ${json['name']} for $chatRoomId' );
              rooms[chatRoomId]?.name = json['name'];
            }
          } else {
            String roomName = "", roomAbout = "";
            if(  json.containsKey('name') ) {
              roomName = json['name'];
            }
            
            if( json.containsKey('about')) {
              roomAbout = json['about'];
            }
            ChatRoom room = ChatRoom(chatRoomId, roomName, roomAbout, "", []);
            rooms[chatRoomId] = room;
            //if( gDebug > 0) print("Added new chat room $chatRoomId with name ${json['name']} .");
          }
        } on Exception catch(e) {
          if( gDebug > 0) print("In From Event. Event type 40. Json Decode error for event id ${ce.eventData.id}. error = $e");
        }
      }
        break;
      default:
        break;  
      } // end switch
  }
 
  /***********************************************************************************************************************************/
  // @method create top level Tree from events. 
  // first create a map. then process each element in the map by adding it to its parent ( if its a child tree)
  factory Tree.fromEvents(Set<Event> events) {
    if( events.isEmpty) {
      return Tree(Event("","",EventData("non","", 0, 0, "", [], [], [], [[]], {}), [""], "[json]"), [], {}, [], false, {}, {});
    }

    // create a map tempChildEventsMap from list of events, key is eventId and value is event itself
    Map<String, Tree> tempChildEventsMap = {};
    events.forEach((event) { 
      // only add in map those kinds that are supported or supposed to be added ( 0 1 3 7 40)
      if( typesInEventMap.contains(event.eventData.kind)) {
        tempChildEventsMap[event.eventData.id] = Tree(event, [], {}, [], false, {}, {}); 
      }
    });

    // once tempChildEventsMap has been created, create connections between them so we get a tree structure from all these events.
    List<Tree>  topLevelTrees = [];// this will become the children of the main top node. These are events without parents, which are printed at top.
    List<String> tempWithoutParent = [];
    Map<String, ChatRoom> rooms = {};

    int numEventsNotPosts = 0; // just for debugging info
    int numKind40Events   = 0;
    int numKind42Events   = 0;
    if( gDebug > 0) print("In Tree from Events: after adding all required events of type ${typesInEventMap} to tempChildEventsMap map, its size = ${tempChildEventsMap.length} ");

    tempChildEventsMap.forEach((newEventId, value) {
      int eKind = value.e.eventData.kind;
      if( eKind == 42 || eKind == 40) {
        handleChannelEvents(rooms, tempChildEventsMap, value.e);
      }

      // only posts, of kind 1, are added to the main tree structure
      if( eKind != 1) {
        numEventsNotPosts++;
        return;
      }

      if(value.e.eventData.eTagsRest.isNotEmpty ) {
        // is not a parent, find its parent and then add this element to that parent Tree
        String parentId = value.e.eventData.getParent();
        if( value.e.eventData.id == gCheckEventId) {
          if(gDebug > 0) print("In Tree FromEvents: got id: $gCheckEventId");
        }

        if(tempChildEventsMap.containsKey( parentId)) {
          if( tempChildEventsMap[parentId]?.e.eventData.kind != 1) { // since parent can only be a kind 1 event
            if( gDebug > 1) log.info("In Tree.fromEvents: Not adding: got a kind 1 event whose parent is not a type 1 post: $newEventId . parent kind: ${tempChildEventsMap[parentId]?.e.eventData.kind}");
            return;
          }
          tempChildEventsMap[parentId]?.addChildNode(value); 
        } else {
           // in case where the parent of the new event is not in the pool of all events, 
           // then we create a dummy event and put it at top ( or make this a top event?) TODO handle so that this can be replied to, and is fetched
           Tree dummyTopNode = Tree(Event("","",
                                          EventData("Unk" ,gDummyAccountPubkey, value.e.eventData.createdAt , 1, "Unknown parent event", [], [], [], [[]], {}),
                                          [""], "[json]"), 
                                    [], {}, [], false, {}, {});
           dummyTopNode.addChildNode(value);
           tempWithoutParent.add(value.e.eventData.id); 
          
           // add the dummy evnets to top level trees, so that their real children get printed too with them
           // so no post is missed by reader
           topLevelTrees.add(dummyTopNode);
        }
      }
    }); // going over tempChildEventsMap and adding children to their parent's .children list

    // add parent trees as top level child trees of this tree
    for( var value in tempChildEventsMap.values) {
        if( value.e.eventData.kind == 1 &&  value.e.eventData.eTagsRest.isEmpty) {  // only posts which are parents
            topLevelTrees.add(value);
        }
    }

    if(gDebug != 0) print("In Tree FromEvents: number of events in map which are not kind 1 = ${numEventsNotPosts}");
    if(gDebug != 0) print("In Tree FromEvents: number of events in map of kind 40 = ${numKind40Events}");
    if(gDebug != 0) print("In Tree FromEvents: number of events in map of kind 42 = ${numKind42Events}");
    if(gDebug != 0) print("In Tree FromEvents: number of events without parent in fromEvents = ${tempWithoutParent.length}");

    // create a dummy top level tree and then create the main Tree object
    Event dummy = Event("","",  EventData("non","", 0, 1, "Dummy Top event. Should not be printed.", [], [], [], [[]], {}), [""], "[json]");
    return Tree( dummy, topLevelTrees, tempChildEventsMap, tempWithoutParent, true, rooms, {});
  } // end fromEvents()

   /***********************************************************************************************************************************/
   /* @insertEvents inserts the given new events into the tree, and returns the id the ones actually 
    * inserted so that they can be printed as notifications
   */
  Set<String> insertEvents(Set<Event> newEventsSetToProcess) {
    if( gDebug > 0) log.info("In insertEvetnts: called for ${newEventsSetToProcess.length} events");

    Set<String> newEventIdsSet = {};

    // add the event to the Tree
    newEventsSetToProcess.forEach((newEvent) { 
      // don't process if the event is already present in the map
      // this condition also excludes any duplicate events sent as newEvents
      if( allChildEventsMap.containsKey(newEvent.eventData.id)) {
        return;
      }

      // handle reaction events and return if we could not find the reacted to. Continue otherwise to add this to notification set newEventIdsSet
      if( newEvent.eventData.kind == 7) {
        if( processReaction(newEvent) == "") {
          if(gDebug > 0) print("In insertEvents: For new reaction ${newEvent.eventData.id} could not find reactedTo or reaction was already present by this reactor");
          return;
        }
      }

      // only kind 0, 1, 3, 7, 40, 42 events are added to map, return otherwise
      if( !typesInEventMap.contains(newEvent.eventData.kind) ) {
        return;
      }

      // expand mentions ( and translate if flag is set) and then add event to main event map
      newEvent.eventData.translateAndExpandMentions();
      eventsNotReadFromFile.add(newEvent.eventData.id); // used later so that only these events are appended to the file

      // add them to the main store of the Tree object
      allChildEventsMap[newEvent.eventData.id] = Tree(newEvent, [], {}, [], false, {}, {});

      // add to new-notification list only if this is a recent event ( because relays may send old events, and we dont want to highlight stale messages)
      if( newEvent.eventData.createdAt > getSecondsDaysAgo(gDontHighlightEventsOlderThan)) {
        newEventIdsSet.add(newEvent.eventData.id);
      }
    });
    
    // now go over the newly inserted event, and add its to the tree for kind 1 events, add 42 events to channels. rest ( such as kind 0, kind 3, kind 7) are ignored.
    newEventIdsSet.forEach((newId) {
      Tree? newTree = allChildEventsMap[newId]; // this should return true because we just inserted this event in the allEvents in block above
      if( newTree != null) {

        switch(newTree.e.eventData.kind) {
          case 1:
            // only kind 1 events are added to the overall tree structure
            if( newTree.e.eventData.eTagsRest.isEmpty) {
                // if its a new parent event, then add it to the main top parents ( this.children)
                children.add(newTree);
            } else {
                // if it has a parent , then add the newTree as the parent's child
                String parentId = newTree.e.eventData.getParent();
                if( allChildEventsMap.containsKey(parentId)) {
                  allChildEventsMap[parentId]?.addChildNode(newTree);
                } else {
                  // create top unknown parent and then add it
                  Tree dummyTopNode = Tree(Event("","",
                                                  EventData("Unk" ,gDummyAccountPubkey, newTree.e.eventData.createdAt , 1, "Unknown parent event", [], [], [], [[]], {}),
                                                            [""], "[json]"), 
                                                [], {}, [], false, {}, {});
                  dummyTopNode.addChildNode(newTree);
                  children.add(dummyTopNode);
                }
            }
            break;
          case 42:
            // add 42 chat message event id to its chat room
            String channelId = newTree.e.eventData.getParent();
            if( channelId != "") {
              if( chatRooms.containsKey(channelId)) {
                if( gDebug > 0) print("added event to chat room in insert event");
                addMessageToChannel(channelId, newTree.e.eventData.id, allChildEventsMap, chatRooms);
                newTree.e.eventData.isNotification = true; // highlight it too in next printing
              }
            } else {
              print("info: in insert events, could not find parent/channel id");
            }
            break;
          default: 
            break;
        }
      }
    });

    if(gDebug > 0) print("In end of insertEvents: Returning ${newEventIdsSet.length} new notification-type events, which are ${newEventIdsSet.length < 10 ? newEventIdsSet: " <had more than 10 elements"} ");
    return newEventIdsSet;
  }

  /***********************************************************************************************************************************/
  /*
   * @printNotifications Add the given events to the Tree, and print the events as notifications
   *                     It should be ensured that these are only kind 1 events
   */
  void printNotifications(Set<String> newEventIdsSet, String userName) {
    if( gDebug > 0) print("Info: in printNotifications: num new evetns = ${newEventIdsSet.length}");

    String strToWrite = "Notifications: ";
    int countNotificationEvents = 0;
    for( var newEventId in newEventIdsSet) {
      int k = (allChildEventsMap[newEventId]?.e.eventData.kind??-1);
      if( k == 7 || k == 1 || k == 42 || k == 40) {
        countNotificationEvents++;
      }

      if(  allChildEventsMap.containsKey(newEventId)) {
        if( gDebug > 0) print( "id = ${ (allChildEventsMap[newEventId]?.e.eventData.id??-1)}");
      } else {
        if( gDebug > 0) print( "Info: could not find event id in map."); // this wont later be processed
      }

    }

    if(gDebug > 0) print("Info: In printNotifications: newEventsId = $newEventIdsSet count17 = $countNotificationEvents");
    
    if( countNotificationEvents == 0) {
      strToWrite += "No new replies/posts.\n";
      stdout.write("${getNumDashes(strToWrite.length - 1)}\n$strToWrite");
      stdout.write("Total posts  : ${count()}\n");
      stdout.write("Signed in as : $userName\n\n");
      return;
    }
    // TODO call count() less
    strToWrite += "Number of new replies/posts = ${newEventIdsSet.length}\n";
    stdout.write("${getNumDashes(strToWrite.length -1 )}\n$strToWrite");
    stdout.write("Total posts  : ${count()}\n");
    stdout.write("Signed in as : $userName\n");
    stdout.write("\nHere are the threads with new replies or new likes: \n\n");
    
    List<Tree> topNotificationTree = []; // collect all top tress to display in this list. only unique tress will be displayed
    newEventIdsSet.forEach((eventID) { 
      
      Tree ?t = allChildEventsMap[eventID];
      if( t == null) {
        // ignore if not in Tree. Should ideally not happen. TODO write warning otherwise
        if( gDebug > 0) print("In printNotifications: Could not find event $eventID in tree");
        return;
      } else {
        switch(t.e.eventData.kind) {
          case 1:
            t.e.eventData.isNotification = true;
            Tree topTree = getTopTree(t);
            topNotificationTree.add(topTree);
            break;
          case 7:
            Event event = t.e;
            if(gDebug >= 0) ("Got notification of type 7");
            String reactorId  = event.eventData.pubkey;
            int    lastEIndex = event.eventData.eTagsRest.length - 1;
            String reactedTo  = event.eventData.eTagsRest[lastEIndex];
            Event? reactedToEvent = allChildEventsMap[reactedTo]?.e;
            if( reactedToEvent != null) {
              Tree? reactedToTree = allChildEventsMap[reactedTo];
              if( reactedToTree != null) {
                reactedToTree.e.eventData.newLikes.add( reactorId);
                Tree topTree = getTopTree(reactedToTree);
                topNotificationTree.add(topTree);
              } else {
                if(gDebug > 0) print("Could not find reactedTo tree");
              }
            } else {
              if(gDebug > 0) print("Could not find reactedTo event");
            }
            break;
          default:
            if(gDebug > 0) print("got an event thats not 1 or 7(reaction). its kind = ${t.e.eventData.kind} count17 = $countNotificationEvents");
            break;
        }
      }
    });

    // remove duplicate top trees
    Set ids = {};
    topNotificationTree.retainWhere((t) => ids.add(t.e.eventData.id));
    
    topNotificationTree.forEach( (t) { 
      t.printTree(0, 0, selectAll); 
      print("\n");
      });
    print("\n");
  }

  /***********************************************************************************************************************************/
  /* The main print tree function. Calls the reeSelector() for every node and prints it( and its children), only if it returns true. 
   */
  int printTree(int depth, var newerThan, fTreeSelector treeSelector) {

    int numPrinted = 0;

    // for the top most tree, create a smaller list which only has recent trees
    //List<Tree> latestTrees = []; // TODO

    if( whetherTopMost) {
      depth = depth - 1;
      children.sort(sortTreeNewestReply); // sorting done only for top most threads. Lower threads aren't sorted so save cpu etc TODO improve top sorting
    } else {
      e.printEvent(depth);
      numPrinted++;
      //latestTrees = children; 
    }

    bool leftShifted = false;
    for( int i = 0; i < children.length; i++) {

      if(!whetherTopMost) {
        stdout.write("\n");  
        printDepth(depth+1);
        stdout.write("|\n");
      } else {
        // continue if this children isn't going to get printed anyway; selector is only called for top most tree
        if( treeSelector(children[i]) == false) {
          continue;
        } 

        int newestChildTime = children[i].getMostRecentTime(0);
        DateTime dTime = DateTime.fromMillisecondsSinceEpoch(newestChildTime *1000);
        //print("comparing $newerThan with $dTime");
        if( dTime.compareTo(newerThan) < 0) {
          continue;
        }
        stdout.write("\n");  
        for( int i = 0; i < gapBetweenTopTrees; i++ )  { 
          stdout.write("\n"); 
        }
      }

      // if the thread becomes too 'deep' then reset its depth, so that its 
      // children will not be displayed too much on the right, but are shifted
      // left by about <leftShiftThreadsBy> places
      if( depth > maxDepthAllowed) {
        depth = maxDepthAllowed - leftShiftThreadsBy;
        printDepth(depth+1);
        stdout.write("<${getNumDashes((leftShiftThreadsBy + 1) * gSpacesPerDepth - 1)}+\n");        
        leftShifted = true;
      }

      numPrinted += children[i].printTree(depth+1, newerThan,  treeSelector);
      if( whetherTopMost && gDebug > 0) { 
        //print("");
        //print(children[i].getMostRecentTime(0));
        //print("-----");
      }
      //if( gDebug > 0) print("at end for loop iteraion: numPrinted = $numPrinted");
    }

    if( leftShifted) {
      stdout.write("\n");
      printDepth(depth+1);
      print(">");
    }

    if( whetherTopMost) {
      print("\n\nTotal posts/replies printed: $numPrinted for last $gNumLastDays days");
    }
    return numPrinted;
  }
  
  /**
   * @printAllChennelsInfo Print one line information about all channels, which are type 40 events ( class ChatRoom)
   */
  void printAllChannelsInfo() {
    print("\n\nChannels/Rooms:");
    printUnderlined("      Channel/Room Name             Num of Messages            Latest Message           ");
    chatRooms.forEach((key, value) {
      String name = "";
      if( value.name == "") {
        name = value.chatRoomId.substring(0, 6);
      } else {
        name = "${value.name} ( ${value.chatRoomId.substring(0, 6)})";
      }

      int numMessages = value.messageIds.length;
      stdout.write("${name} ${getNumSpaces(32-name.length)}          $numMessages${getNumSpaces(12- numMessages.toString().length)}"); 
      List<String> messageIds = value.messageIds;
      for( int i = messageIds.length - 1; i >= 0; i++) {
        if( allChildEventsMap.containsKey(messageIds[i])) {
          Event? e = allChildEventsMap[messageIds[i]]?.e;
          if( e!= null) {
            //e.printEvent(0);
            stdout.write("${e.eventData.getAsLine()}");
            break; // print only one event, the latest one
          }
        }
      }
      print("");
    });
  }

  void printChannel(ChatRoom room, [int page = 1])  {
    if( page < 1) {
      if( gDebug > 0) log.info("In printChannel got page = $page");
      page = 1;
    }

    String displayName = room.chatRoomId;
    if( room.name != "") {
      displayName = "${room.name} ( ${displayName.substring(0, 6)} )";
    }

    int lenDashes = 10;
    String str = getNumSpaces(gNumLeftMarginSpaces + 10) + getNumDashes(lenDashes) + displayName + getNumDashes(lenDashes);
    print(" ${getNumSpaces(gNumLeftMarginSpaces + displayName.length~/2 + 4)}In Channel");
    print("\n$str\n");

    
    int i = 0, startFrom = 0, endAt = room.messageIds.length;
    int numPages = 1;

    if( room.messageIds.length > gNumChannelMessagesToShow ) {
      endAt = room.messageIds.length - (page - 1) * gNumChannelMessagesToShow;
      if( endAt < gNumChannelMessagesToShow) endAt = gNumChannelMessagesToShow;
      startFrom = endAt - gNumChannelMessagesToShow;
      numPages = (room.messageIds.length ~/ gNumChannelMessagesToShow) + 1;
      if( page > numPages) {
        page = numPages;
      }
    }
    if( gDebug > 0) print("StartFrom $startFrom  endAt $endAt  numPages $numPages room.messageIds.length = ${room.messageIds.length}");
    for( i = startFrom; i < endAt; i++) {
      String eId = room.messageIds[i];
      Event? e = allChildEventsMap[eId]?.e;
      if( e!= null) {
        e.printEvent(0);
        print("");
      }
    }

    if( room.messageIds.length > gNumChannelMessagesToShow) {
      print("\n");
      printDepth(0);
      stdout.write("${gNotificationColor}Displayed page number ${page} (out of total $numPages pages, where 1st is the latest 'page').\n");
      printDepth(0);
      stdout.write("To see older pages, enter numbers from 1-${numPages}.${gColorEndMarker}\n\n");
    }
  }

  // shows the given channelId, where channelId is prefix-id or channel name as mentioned in room.name. returns full id of channel.
  String showChannel(String channelId, [int page = 1]) {
    
    for( String key in chatRooms.keys) {
      if( key.substring(0, channelId.length) == channelId ) {
        ChatRoom? room = chatRooms[key];
        if( room != null) {
          printChannel(room, page);
        }
        return key;
      }
    }

    // since channelId was not found in channel id, search for it in channel name
    for( String key in chatRooms.keys) {
        ChatRoom? room = chatRooms[key];
        if( room != null) {
          if( room.name.length < channelId.length) {
            continue;
          }
          if( gDebug > 0) print("room = ${room.name} channelId = $channelId");
          if( room.name.substring(0, channelId.length) == channelId ) {
            printChannel(room);
            return key;
          }
        }
    }
    return "";
  }

  // Write the tree's events to file as one event's json per line
  Future<void> writeEventsToFile(String filename) async {
    //print("opening $filename to write to");
    try {
      final File file         = File(filename);
      
      // empty the file
      await  file.writeAsString("", mode: FileMode.writeOnlyAppend).then( (file) => file);
      int        eventCounter = 0;
      String     nLinesStr    = "";
      int        countPosts   = 0;

      const int  numLinesTogether = 100; // number of lines to write in one write call
      int        linesWritten = 0;
      print("eventsNotReadFromFile = ${eventsNotReadFromFile.length}");
      for( var k in eventsNotReadFromFile) {
        Tree? t = allChildEventsMap[k];
        if( t != null) {
          // only write if its not too old
          if( gDontWriteOldEvents) {
            if( t.e.eventData.createdAt < (DateTime.now().subtract(Duration(days: gDontSaveBeforeDays)).millisecondsSinceEpoch ~/ 1000)) {
              continue;
            }
          }

          String line = "${t.e.originalJson}\n";
          nLinesStr += line;
          eventCounter++;
          if( t.e.eventData.kind == 1) {
            countPosts++;
          }
        }

        if( eventCounter % numLinesTogether == 0) {
          await  file.writeAsString(nLinesStr, mode: FileMode.append).then( (file) => file);
          nLinesStr = "";
          linesWritten += numLinesTogether;
        }
      }

      if(  eventCounter > linesWritten) {
        await  file.writeAsString(nLinesStr, mode: FileMode.append).then( (file) => file);
        nLinesStr = "";
      }

      print("\n\nWrote total $eventCounter events to file \"$gEventsFilename\" of which ${countPosts} are posts.")  ; // TODO remove extra 1
    } on Exception catch (e) {
      print("Could not open file $filename.");
      if( gDebug > 0) print("Could not open file: $e");
    }      
    
    return;
  }

  /*
   * @getTagsFromEvent Searches for all events, and creates a json of e-tag type which can be sent with event
   *                   Also adds 'client' tag with application name.
   * @parameter replyToId First few letters of an event id for which reply is being made
   */
  String getTagStr(String replyToId, String clientName) {
    clientName = (clientName == "")? "nostr_console": clientName; // in case its empty 
    if( replyToId.isEmpty) {
      return '["client","$clientName"]';
    }

    String strTags = "";

    // find the latest event with the given id; needs to be done because we allow user to refer to events with as few as 3 or so first letters
    // and only the event that's latest is considered as the intended recipient ( this is not perfect, but easy UI)
    int latestEventTime = 0;
    String latestEventId = "";
    for(  String k in allChildEventsMap.keys) {
      if( k.length >= replyToId.length && k.substring(0, replyToId.length) == replyToId) {
        // ignore future events TODO

        if( ( allChildEventsMap[k]?.e.eventData.createdAt ?? 0) > latestEventTime ) {
          latestEventTime = allChildEventsMap[k]?.e.eventData.createdAt ?? 0;
          latestEventId = k;
        }
      }
    }

    // in case we are given valid length id, but we can't find the event in our internal db, then we just send the reply to given id
    if( latestEventId.isEmpty && replyToId.length == 64) {
      latestEventId = replyToId;  
    }
    if( latestEventId.isEmpty && replyToId.length != 64 && replyToId.length != 0) {
      return "";
    }

    // found the id of event we are replying to
    if( latestEventId.isNotEmpty) {
      String? pTagPubkey = allChildEventsMap[latestEventId]?.e.eventData.pubkey;
      if( pTagPubkey != null) {
        strTags += '["p","$pTagPubkey"],';
      }
      String relay = getRelayOfUser(userPublicKey, pTagPubkey??"");
      relay = (relay == "")? defaultServerUrl: relay;
      String rootEventId = "";

      // nip 10: first e tag should be the id of the top/parent event. 2nd ( or last) e tag should be id of the event being replied to.
      Tree? t = allChildEventsMap[latestEventId];
      if( t != null) {
        Tree topTree = getTopTree(t);
        rootEventId = topTree.e.eventData.id;
        if( rootEventId != latestEventId) { // if the reply is to a top/parent event, then only one e tag is sufficient
          strTags +=  '["e","$rootEventId"],';
        }
      }
      strTags +=  '["e","$latestEventId","$relay"],';
    }

    strTags += '["client","$clientName"]' ;
    return strTags;
  }

  // counts all valid events in the tree: ignores the dummy nodes that are added for events which aren't yet known
  int count() {
    int totalCount = 0;
    // ignore dummy events
    if(!whetherTopMost) {
      if( e.eventData.pubkey != gDummyAccountPubkey) // don't count dummy parents
        totalCount = 1;
    }
    for(int i = 0; i < children.length; i++) {
      totalCount += children[i].count(); // then add all the children
    }
    return totalCount;
  }

  void addChild(Event child) {
    Tree node;
    node = Tree(child, [], {}, [], false, {}, {});
    children.add(node);
  }

  void addChildNode(Tree node) {
    children.add(node);
  }

  // for any tree node, returns its top most parent
  Tree getTopTree(Tree t) {
    while( true) {
      Tree? parent =  allChildEventsMap[ t.e.eventData.getParent()];
      if( parent != null) {
        t = parent;
      } else {
        break;
      }
    }
    return t;
  }

  // returns the time of the most recent comment
  int getMostRecentTime(int mostRecentTime) {
    int initial = mostRecentTime;
    if( children.isEmpty)   {
      return e.eventData.createdAt;
    }
    if( e.eventData.createdAt > mostRecentTime) {
      mostRecentTime = e.eventData.createdAt;
    }

    int mostRecentIndex = -1;
    for( int i = 0; i < children.length; i++) {
      int mostRecentChild = children[i].getMostRecentTime(mostRecentTime);
      if( mostRecentTime <= mostRecentChild) {
        if( gDebug > 0 && children[i].e.eventData.id == "970bbd22e63000dc1313867c61a50e0face728139afe6775fa9fe4bc61bdf664") {
          //print("plantimals 970bbd22e63000dc1313867c61a50e0face728139afe6775fa9fe4bc61bdf664");
          //print( "children[i].e.eventData. = ${children[i].e.eventData.createdAt} mostRecentChild = $mostRecentChild i = $i mostRecentIndex = $mostRecentIndex mostRecentTime = $mostRecentTime\n");
          //printTree(0, 0, (a) => true);
          //print("--------------");
        }

        mostRecentTime = mostRecentChild;
        mostRecentIndex = i;
      }
    }
    if( mostRecentIndex == -1) { 
      Tree top = getTopTree(this);
      if( gDebug ==2 ) {
        print('\nerror: returning newer child id = ${e.eventData.id}. e.eventData.createdAt = ${e.eventData.createdAt} num child = ${children.length} 1st child time = ${children[0].e.eventData.createdAt} mostRecentTime = $mostRecentTime initial time = $initial ');
        print("its top event time and id = time ${top.e.eventData.createdAt} id ${top.e.eventData.id} num tags = ${top.e.eventData.tags} num e tags = ${top.e.eventData.eTagsRest}\n");
        //top.printTree(0,0, (a) => true);
        print("\n-----------------------------------------------------------------------\n");
      }
      // typically this should not happen. child nodes/events can't be older than parents 
      return e.eventData.createdAt;
    } else {
      return mostRecentTime;
    }
  }

  // returns true if the treee or its children has a reply or like for the user with public key pk; and notification flags are set for such events
  bool hasRepliesAndLikes(String pk) {
    //print("----- pk = $pk");
    bool hasReaction = false;
    bool childMatches = false;

    if( e.eventData.pubkey == pk &&  gReactions.containsKey(e.eventData.id)) {
      List<List<String>>? reactions = gReactions[e.eventData.id];
      if( reactions  != null) {
        if( reactions.length > 0) {
          //print("has reactions");
          reactions.forEach((reaction) {  
            // dont add notificatoin for self reaction
            Event? reactorEvent = allChildEventsMap[reaction[0]]?.e;
            if( reactorEvent != null) {
              if( reactorEvent.eventData.pubkey != pk){ // ignore self likes 
                e.eventData.newLikes.add(reaction[0]);
                hasReaction = true;
              }
            }
          });
        }
      }
    }

    if( e.eventData.pubkey == pk && children.length > 0) {
      for( int i = 0; i < children.length; i++ ) {
        children.forEach((child) {  
          // if child is someone else then set notifications and flag, means there are replies to this event 
          childMatches = child.e.eventData.isNotification =  ((child.e.eventData.pubkey != pk)? true: false) ; 
        }); 
      }
    }

    for( int i = 0; i < children.length; i++ ) {
      if( children[i].hasRepliesAndLikes(pk)) {
        childMatches = true;
      }
    }

    if( hasReaction || childMatches) {
      //print("returning true");
      return true;
    }
    return false;
  } 


  // returns true if the treee or its children has a post or like by user; and notification flags are set for such events
  bool hasUserPostAndLike(String pubkey) {
    bool hasReacted = false;

    if( gReactions.containsKey(e.eventData.id))  {
      List<List<String>>? reactions = gReactions[e.eventData.id];
      if( reactions  != null) {
        for( int i = 0; i < reactions.length; i++) {
          if( reactions[i][0] == pubkey) {
            e.eventData.newLikes.add(pubkey);
            hasReacted = true;
            break;
          }
        }
      }
    }

    bool childMatches = false;
    for( int i = 0; i < children.length; i++ ) {
      if( children[i].hasUserPostAndLike(pubkey)) {
        childMatches = true;
      }
    }
    if( e.eventData.pubkey == pubkey) {
      e.eventData.isNotification = true;
      return true;
    }
    if( hasReacted || childMatches) {
      return true;
    }
    return false;
  } 

  // returns true if the given words exists in it or its children
  bool hasWords(String word) {
    if( e.eventData.content.length > 2000) { // ignore if content is too large, takes lot of time
      return false;
    }

    bool childMatches = false;
    for( int i = 0; i < children.length; i++ ) {
      // ignore too large comments
      if( children[i].e.eventData.content.length > 2000) {
        continue;
      }

      if( children[i].hasWords(word)) {
        childMatches = true;
      }
    }

    if( e.eventData.content.toLowerCase().contains(word) || e.eventData.id == word ) {
      e.eventData.isNotification = true;
      return true;
    }
    if( childMatches) {
      return true;
    }
    return false;
  } 

  // returns true if the event or any of its children were made from the given client, and they are marked for notification
  bool fromClientSelector(String clientName) {
    //if(gDebug > 0) print("In tree selector hasWords: this id = ${e.eventData.id} word = $word");

    bool byClient = false;
    List<List<String>> tags = e.eventData.tags;
    for( int i = 0; i < tags.length; i++) {
      if( tags[i].length < 2) {
        continue;
      }
      if( tags[i][0] == "client" && tags[i][1].contains(clientName)) {
        e.eventData.isNotification = true;
        byClient = true;
        break;
      }
    }

    bool childMatch = false;
    for( int i = 0; i < children.length; i++ ) {
      if( children[i].fromClientSelector(clientName)) {
        childMatch = true;
      }
    }
    if( byClient || childMatch) {
      //print("SOME matched $clientName ");
      return true;
    }
    //print("none matched $clientName ");

    return false;
  } 

/*
  Event? getContactEvent(String pkey) {
      // get the latest kind 3 event for the user, which lists his 'follows' list
      int latestContactsTime = 0;
      String latestContactEvent = "";

      allChildEventsMap.forEach((key, value) {
        if( value.e.eventData.pubkey == pkey && value.e.eventData.kind == 3 && latestContactsTime < value.e.eventData.createdAt) {
          latestContactEvent = value.e.eventData.id;
          latestContactsTime = value.e.eventData.createdAt;
        }
      });

      // if contact list was found, get user's feed, and keep the contact list for later use 
      if (latestContactEvent != "") {
        if( gDebug > 1) {
          //print("latest contact event : $latestContactEvent with total contacts = ${allChildEventsMap[latestContactEvent]?.e.eventData.contactList.length}");
          //print(allChildEventsMap[latestContactEvent]?.e.originalJson);
        }
        return allChildEventsMap[latestContactEvent]?.e;
      }

      return null;
  }
*/
  // TODO inefficient; fix
  List<String> getFollowers(String pubkey) {
    if( gDebug > 0) print("Finding followrs for $pubkey");
    List<String> followers = [];

    Set<String> usersWithContactList = {};
    allChildEventsMap.forEach((key, value) {
      if( value.e.eventData.kind == 3) {
        usersWithContactList.add(value.e.eventData.pubkey);
      }
    });

    usersWithContactList.forEach((x) { 
      Event? contactEvent = getContactEvent(x);

      if( contactEvent != null) {
        List<Contact> contacts = contactEvent.eventData.contactList;
        for(int i = 0; i < contacts.length; i ++) {
          if( contacts[i].id == pubkey) {
            followers.add(x);
            return;
          }
        }
      }
    });

    return followers;
  }

  // finds all your followers, and then finds which of them follow the otherPubkey
  void printSocialDistance(String otherPubkey, String otherName) {
    String otherName = getAuthorName(otherPubkey);

    Event? contactEvent = getContactEvent(userPublicKey);
    bool isFollow = false;
    int  numSecond = 0; // number of your follows who follow the other

    int numContacts =  0;
    if( contactEvent != null) {
      List<Contact> contacts = contactEvent.eventData.contactList;
      numContacts = contacts.length;
      for(int i = 0; i < contacts.length; i ++) {
        // check if you follow the other account
        if( contacts[i].id == otherPubkey) {
          isFollow = true;
        }
        // count the number of your contacts who know or follow the other account
        List<Contact> followContactList = [];
        Event? followContactEvent = getContactEvent(contacts[i].id);
        if( followContactEvent != null) {
          followContactList = followContactEvent.eventData.contactList;
          for(int j = 0; j < followContactList.length; j++) {
            if( followContactList[j].id == otherPubkey) {
              numSecond++;
              break;
            }
          }
        }
      }// end for loop through users contacts
      if( isFollow) {
        print("* You follow $otherName ");
      } else {
        print("* You don't follow $otherName");
      }
      print("* Of the $numContacts people you follow, $numSecond follow $otherName");

    } // end if contact event was found
  }
} // end Tree

void addMessageToChannel(String channelId, String messageId, var tempChildEventsMap, var chatRooms) {
  //chatRooms[channelId]?.messageIds.add(newTree.e.eventData.id);
  int newEventTime = (tempChildEventsMap[messageId]?.e.eventData.createdAt??0);

  if( chatRooms.containsKey(channelId)) {
    ChatRoom? room = chatRooms[channelId];
    if( room != null ) {
      if( room.messageIds.isEmpty) {
        //if(gDebug> 0) print("room is empty. adding new message and returning. ");
        room.messageIds.add(messageId);
        return;
      }
      
      if(gDebug> 0) print("room has ${room.messageIds.length} messages already. adding new one to it. ");

      for(int i = 0; i < room.messageIds.length; i++) {
        int eventTime = (tempChildEventsMap[room.messageIds[i]]?.e.eventData.createdAt??0);
        if( newEventTime < eventTime) {
          // shift current i and rest one to the right, and put event Time here
          if(gDebug> 0) print("In addMessageToChannel: inserted in middle to channel ${room.chatRoomId} ");
          room.messageIds.insert(i, messageId);
          return;
        }
      }
      if(gDebug> 0) print("In addMessageToChannel: added to channel ${room.chatRoomId} ");

      // insert at end
      room.messageIds.add(messageId);
      return;
    } else {
      print("In addMessageToChannel: could not find room");
    }
  } else {
    print("In addMessageToChannel: could not find channel id");
  }
  print("In addMessageToChannel: returning without inserting message");
}

int ascendingTimeTree(Tree a, Tree b) {
  if(a.e.eventData.createdAt < b.e.eventData.createdAt) {
    return -1;
  } else {
    if( a.e.eventData.createdAt == b.e.eventData.createdAt) {
      return 0;
    }
  }
  return 1;
}

// sorter function that looks at the latest event in the whole tree including the/its children
int sortTreeNewestReply(Tree a, Tree b) {
  int aMostRecent = a.getMostRecentTime(0);
  int bMostRecent = b.getMostRecentTime(0);

  if(aMostRecent < bMostRecent) {
    return -1;
  } else {
    if( aMostRecent == bMostRecent) {
      return 0;
    } else {
        return 1;
    }
  }
}

// for the given reaction event of kind 7, will update the global gReactions appropriately, returns 
// the reactedTo event's id, blank if invalid reaction etc
String processReaction(Event event) {
  if( event.eventData.kind == 7 
    && event.eventData.eTagsRest.isNotEmpty) {
    if(gDebug > 1) ("Got event of type 7"); // this can be + or !, which means 'hide' event for me
    String reactorId  = event.eventData.pubkey;
    String comment    = event.eventData.content;
    int    lastEIndex = event.eventData.eTagsRest.length - 1;
    String reactedTo  = event.eventData.eTagsRest[lastEIndex];

    if( event.eventData.content == "+") {
      if( gReactions.containsKey(reactedTo)) {
        // check if the reaction already exists by this user
        for( int i = 0; i < ((gReactions[reactedTo]?.length)??0); i++) {
          List<String> oldReaction = (gReactions[reactedTo]?[i])??[];
          if( oldReaction.length == 2) {
            //valid reaction
            if(oldReaction[0] == reactorId) {
              return ""; // reaction by this user already exists so return
            }
          }
        }

        List<String> temp = [reactorId, comment];
        gReactions[reactedTo]?.add(temp);
      } else {
        // first reaction + to this event, create the entry in global map
        List<List<String>> newReactorList = [];
        List<String> temp = [reactorId, comment];
        newReactorList.add(temp);
        gReactions[reactedTo] = newReactorList;
      }
    } else {
      if( event.eventData.content == "!") {
        //reactedTo needs to ve hidden if we have it in the main tree map
        // Tree? treeReactedTo = 

      }
    }
    return reactedTo;
  } else {
    // case where its not a kind 7 event, or we can't find the reactedTo event due to absense of e tag.

  }

  return "";
}

// will go over the list of events, and update the global gReactions appropriately
void processReactions(Set<Event> events) {
  for (Event event in events) {
    processReaction(event);
  }
  return;
}

/*
 * @function getTree Creates a Tree out of these received List of events. 
 *             Will remove duplicate events( which should not ideally exists because we have a set), 
 *             populate global names, process reactions, remove bots, translate, and then create main tree
 */
Tree getTree(Set<Event> events) {
    if( events.isEmpty) {
      print("Warning: In printEventsAsTree: events length = 0");
      return Tree(Event("","",EventData("non","", 0, 0, "", [], [], [], [[]], {}), [""], "[json]"), [], {}, [], true, {}, {});
    }

    // remove all events other than kind 0 (meta data), 1(posts replies likes), 3 (contact list), 7(reactions), 40 and 42 (chat rooms)
    events.removeWhere( (event) => !Tree.typesInEventMap.contains(event.eventData.kind));  

    // process kind 0 events about metadata 
    int totalKind0Processed = 0, notProcessed = 0;
    events.forEach( (event) =>  processKind0Event(event)? totalKind0Processed++: notProcessed++);
    if( gDebug > 0) print("In getTree: totalKind0Processed = $totalKind0Processed  notProcessed = $notProcessed gKindONames.length = ${gKindONames.length}"); 

    // process kind 3 events which is contact list. Update global info about the user (with meta data) 
    int totalKind3Processed = 0, notProcessed3 = 0;
    events.forEach( (event) =>  processKind3Event(event)? totalKind3Processed++: notProcessed3++);
    if( gDebug > 0) print("In getTree: totalKind3Processed = $totalKind3Processed  notProcessed = $notProcessed3 gKindONames.length = ${gKindONames.length}"); 

    // process kind 7 events or reactions
    processReactions(events);

    // remove bot events
    events.removeWhere( (event) => gBots.contains(event.eventData.pubkey));

    // remove duplicate events
    Set ids = {};
    events.retainWhere((event) => ids.add(event.eventData.id));

    // translate and expand mentions for all
    events.forEach( (event) => event.eventData.translateAndExpandMentions());

    if( gDebug > 0) print("In getTree: after removing unwanted kind, number of events remaining: ${events.length}");

    // create tree from events
    Tree node = Tree.fromEvents(events);

    if(gDebug != 0) print("total number of posts/replies in main tree = ${node.count()}");
    return node;
}
