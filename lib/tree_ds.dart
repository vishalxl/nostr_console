import 'dart:io';
import 'package:nostr_console/event_ds.dart';


typedef fTreeSelector = bool Function(Tree a);

bool selectAll(Tree t) {
  //print("In select all");
  return true;
}

class Tree {
  Event             e;
  List<Tree>        children;
  Map<String, Tree> allChildEventsMap;
  List<String>      eventsWithoutParent;
  bool              whetherTopMost;
  Tree(this.e, this.children, this.allChildEventsMap, this.eventsWithoutParent, this.whetherTopMost);

  static const List<int>   typesInEventMap = [0, 1, 3, 7]; // 0 meta, 1 post, 3 follows list, 7 reactions

  // @method create top level Tree from events. 
  // first create a map. then process each element in the map by adding it to its parent ( if its a child tree)
  factory Tree.fromEvents(List<Event> events) {
    if( events.isEmpty) {
      return Tree(Event("","",EventData("non","", 0, 0, "", [], [], [], [[]], {}), [""], "[json]"), [], {}, [], false);
    }

    // create a map from list of events, key is eventId and value is event itself
    Map<String, Tree> allChildEventsMap = {};
    events.forEach((event) { 
      // only add in map those kinds that are supported or supposed to be added ( 0 1 3 7)
      if( typesInEventMap.contains(event.eventData.kind)) {
        allChildEventsMap[event.eventData.id] = Tree(event, [], {}, [], false); 
      }
    });

    // this will become the children of the main top node. These are events without parents, which are printed at top.
    List<Tree>  topLevelTrees = [];

    List<String> tempWithoutParent = [];
    allChildEventsMap.forEach((key, value) {

      // only posts areadded to this tree structure
      if( value.e.eventData.kind != 1) {
        return;
      }

      if(value.e.eventData.eTagsRest.isNotEmpty ) {
        // is not a parent, find its parent and then add this element to that parent Tree
        //stdout.write("added to parent a child\n");
        String id = key;
        String parentId = value.e.eventData.getParent();
        if( allChildEventsMap.containsKey(parentId)) {
        }

        if(allChildEventsMap.containsKey( parentId)) {
          if( allChildEventsMap[parentId]?.e.eventData.kind != 1) { // since parent can only be a kind 1 event
            print("In fromEvents: got an event whose parent is not a type 1 post: $id");
            return;
          }

          allChildEventsMap[parentId]?.addChildNode(value); // in this if condition this will get called
        } else {
           // in case where the parent of the new event is not in the pool of all events, 
           // then we create a dummy event and put it at top ( or make this a top event?) TODO handle so that this can be replied to, and is fetched
           Tree dummyTopNode = Tree(Event("","",EventData("Unk" ,gDummyAccountPubkey, value.e.eventData.createdAt , 1, "Unknown parent event", [], [], [], [[]], {}), [""], "[json]"), [], {}, [], false);
           dummyTopNode.addChildNode(value);
           tempWithoutParent.add(value.e.eventData.id); 
          
           // add the dummy evnets to top level trees, so that their real children get printed too with them
           // so no post is missed by reader
           topLevelTrees.add(dummyTopNode);
        }
      }
    });

    // add parent trees as top level child trees of this tree
    for( var value in allChildEventsMap.values) {
        if( value.e.eventData.kind == 1 &&  value.e.eventData.eTagsRest.isEmpty) {  // only posts which are parents
            topLevelTrees.add(value);
        }
    }

    if(gDebug != 0) print("number of events without parent in fromEvents = ${tempWithoutParent.length}");

    Event dummy = Event("","",  EventData("non","", 0, 1, "Dummy Top event. Should not be printed.", [], [], [], [[]], {}), [""], "[json]");
    return Tree( dummy, topLevelTrees, allChildEventsMap, tempWithoutParent, true); // TODO remove events[0]
  } // end fromEvents()

  /*
   * @insertEvents inserts the given new events into the tree, and returns the id the ones actually inserted
   */
  List<String> insertEvents(List<Event> newEvents) {

    List<String> newEventsId = [];

    // add the event to the Tree
    newEvents.forEach((newEvent) { 
      // don't process if the event is already present in the map
      // this condition also excludes any duplicate events sent as newEvents
      if( allChildEventsMap.containsKey(newEvent.eventData.id)) {
        return;
      }

      // handle reaction events and return
      if( newEvent.eventData.kind == 7) {
        String reactedTo = processReaction(newEvent);
        
        if( reactedTo != "") {
          newEventsId.add(newEvent.eventData.id); // add here to process/give notification about this new reaction
          if(gDebug > 0) print("In insertEvents: got a new reaction by: ${newEvent.eventData.id} to $reactedTo");
        } else {
          if(gDebug > 0) print("In insertEvents: For new reaction ${newEvent.eventData.id} could not find reactedTo");
          return;
        }
      }

      // only kind 0, 1, 3, 7 events are added to map, return otherwise
      if( !typesInEventMap.contains(newEvent.eventData.kind) ) {
        return;
      }

      // expand mentions ( and translate if flag is set)
      newEvent.eventData.translateAndExpandMentions();

      if( gDebug > 0) print("In insertEvents: adding event to main children map");
      allChildEventsMap[newEvent.eventData.id] = Tree(newEvent, [], {}, [], false); 
      newEventsId.add(newEvent.eventData.id);
    });
    
    // now go over the newly inserted event, and add its to the tree. only for kind 1 events
    newEventsId.forEach((newId) {
      Tree? newTree = allChildEventsMap[newId]; // this should return true because we just inserted this event in the allEvents in block above
      if( newTree != null) {
        // only kind 1 events are added to the overall tree structure
        if( newTree.e.eventData.kind != 1) {
          return;
        }

        // kind 1 events are added to the tree structure
        if( newTree.e.eventData.eTagsRest.isEmpty) {
            // if its a is a new parent event, then add it to the main top parents ( this.children)
            children.add(newTree);
        } else {
            // if it has a parent , then add the newTree as the parent's child
            String parentId = newTree.e.eventData.getParent();
            allChildEventsMap[parentId]?.addChildNode(newTree);
        }
      }
    });

    if(gDebug > 0) print("In insertEvents: Found new ${newEventsId.length} events. ");

    return newEventsId;
  }


  int printTree(int depth, var newerThan, fTreeSelector treeSelector) {

    int numPrinted = 0;
    children.sort(sortTreeNewestReply);

    if( !whetherTopMost) {
      e.printEvent(depth);
      numPrinted++;
    } else {
      depth = depth - 1;
    }

    bool leftShifted = false;
    for( int i = 0; i < children.length; i++) {
      // continue if this children isn't going to get printed anyway
      //if( gDebug > 0) print("going to call tree selector");
      if( !treeSelector(children[i])) {
        continue;
      }

      if(!whetherTopMost) {
        stdout.write("\n");  
        printDepth(depth+1);
        stdout.write("|\n");
      } else {


        Tree newestChild = children[i].getMostRecent(0);
        DateTime dTime = DateTime.fromMillisecondsSinceEpoch(newestChild.e.eventData.createdAt *1000);
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
      if( whetherTopMost && gDebug != 0) { 
        print(children[i].getMostRecent(0).e.eventData.createdAt);
      }
      //if( gDebug > 0) print("at end for loop iteraion: numPrinted = $numPrinted");
    }

    if( leftShifted) {
      stdout.write("\n");
      printDepth(depth+1);
      print(">");
    }

    if( whetherTopMost) {
      print("\nTotal posts/replies printed: $numPrinted for last $gNumLastDays days");
    }


    return numPrinted;
  }

  /*
   * @printNotifications Add the given events to the Tree, and print the events as notifications
   *                     It should be ensured that these are only kind 1 events
   */
  void printNotifications(List<String> newEventsId, String userName) {
    // remove duplicates
    Set temp = {};
    newEventsId.retainWhere((event) => temp.add(newEventsId));
    
    String strToWrite = "Notifications: ";
    int count17 = 0;
    for( int i =0 ; i < newEventsId.length; i++) {
      if( (allChildEventsMap[newEventsId[i]]?.e.eventData.kind??-1) == 7 || (allChildEventsMap[newEventsId[i]]?.e.eventData.kind??-1) == 1) {
        count17++;
      }

      if(  allChildEventsMap.containsKey(newEventsId[i])) {
        if( gDebug > 0) print( "id = ${ (allChildEventsMap[newEventsId[i]]?.e.eventData.id??-1)}");
      } else {
        if( gDebug > 0) print( "could not find event id in map");
      }

    }
    // TODO don't print notifications for events that are too old

    if(gDebug > 0) print("Info: In printNotifications: newEventsId = $newEventsId count17 = $count17");
    
    if( count17 == 0) {
      strToWrite += "No new replies/posts.\n";
      stdout.write("${getNumDashes(strToWrite.length - 1)}\n$strToWrite");
      stdout.write("Total posts  : ${count()}\n");
      stdout.write("Signed in as : $userName\n\n");
      return;
    }
    // TODO call count() less
    strToWrite += "Number of new replies/posts = ${newEventsId.length}\n";
    stdout.write("${getNumDashes(strToWrite.length -1 )}\n$strToWrite");
    stdout.write("Total posts  : ${count()}\n");
    stdout.write("Signed in as : $userName\n");
    stdout.write("\nHere are the threads with new replies or new likes: \n\n");
    
    List<Tree> topTrees = []; // collect all top tress to display in this list. only unique tress will be displayed
    newEventsId.forEach((eventID) { 
      
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
            topTrees.add(topTree);
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
                topTrees.add(topTree);
              } else {
                if(gDebug > 0) print("Could not find reactedTo tree");
              }
            } else {
              if(gDebug > 0) print("Could not find reactedTo event");
            }
            break;
          default:
            if(gDebug > 0) print("got an event thats not 1 or 7(reaction). its id = ${t.e.eventData.kind} count17 = $count17");
            break;
        }
      }
    });

    // remove duplicate top trees
    Set ids = {};
    topTrees.retainWhere((t) => ids.add(t.e.eventData.id));
    
    topTrees.forEach( (t) { t.printTree(0, 0, selectAll); });
    print("\n");
  }

  // Write the tree's events to file as one event's json per line
  Future<void> writeEventsToFile(String filename) async {
    //print("opening $filename to write to");
    try {
      final File file         = File(filename);
      
      // empty the file
      await  file.writeAsString("", mode: FileMode.writeOnly).then( (file) => file);
      int        eventCounter = 0;
      String     nLinesStr    = "";
      int        countPosts   = 0;

      const int  numLinesTogether = 100; // number of lines to write in one write call
      int        linesWritten = 0;
      for( var k in allChildEventsMap.keys) {
        Tree? t = allChildEventsMap[k];
        if( t != null) {
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

      //int len = await file.length();
      print("\n\nWrote total $eventCounter events to file \"$gEventsFilename\" of which ${countPosts + 1} are posts.")  ; // TODO remove extra 1
    } on Exception catch (err) {
      print("Could not open file $filename.");
    }      
    
    return;
  }

  /*
   * @getTagsFromEvent Searches for all events, and creates a json of e-tag type which can be sent with event
   *                   Also adds 'client' tag with application name.
   * @parameter replyToId First few letters of an event id for which reply is being made
   */
  String getTagStr(String replyToId, String clientName) {
    String strTags = "";
    clientName = clientName == ""? "nostr_console": clientName; // in case its empty 

    if( replyToId.isEmpty) {
      strTags += '["client","$clientName"]' ;
      return strTags;
    }

    // find the latest event with the given id
    int latestEventTime = 0;
    String latestEventId = "";
    for(  String k in allChildEventsMap.keys) {
      //print("$k $replyToId");
      if( k.length >= replyToId.length && k.substring(0, replyToId.length) == replyToId) {
        if( ( allChildEventsMap[k]?.e.eventData.createdAt ?? 0) > latestEventTime ) {
          latestEventTime = allChildEventsMap[k]?.e.eventData.createdAt ?? 0;
          latestEventId = k;
        }
      }
    }

    strTags += '["client","$clientName"]' ;
    if( latestEventId.isNotEmpty) {
      String? pTagPubkey = allChildEventsMap[latestEventId]?.e.eventData.pubkey;
      if( pTagPubkey != null) {
        strTags += ',["p","$pTagPubkey"]';
      }

      String relay = getRelayOfUser(userPublicKey, pTagPubkey??"");
      relay = (relay == "")? defaultServerUrl: relay;
      strTags +=  ',["e","$latestEventId","$relay"]';
    }
    
    return strTags;
  }
 
  int count() {
    int totalCount = 0;
    // ignore dummy events
    if(e.eventData.pubkey != gDummyAccountPubkey) {
      totalCount = 1;
    }

    for(int i = 0; i < children.length; i++) {
      totalCount += children[i].count(); // then add all the children
    }
    return totalCount;
  }

  void addChild(Event child) {
    Tree node;
    node = Tree(child, [], {}, [], false);
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
  Tree getMostRecent(int mostRecentTime) {
    if( children.isEmpty)   {
      return this;
    }

    if( e.eventData.createdAt > mostRecentTime) {
      mostRecentTime = e.eventData.createdAt;
    }

    int mostRecentIndex = -1;
    for( int i = 0; i < children.length; i++) {
      int mostRecentChild = children[i].getMostRecent(mostRecentTime).e.eventData.createdAt;
      if( mostRecentTime <= mostRecentChild) {
        mostRecentTime = mostRecentChild;
        mostRecentIndex = i;
      }
    }

    if( mostRecentIndex == -1) {
      // typically this should not happen. child nodes/events can't be older than parents 
      return this;
    } else {
      return children[mostRecentIndex];
    }
  }

  // returns true if the treee or its children has a post by user
  bool hasUserPost(String pubkey) {
    if( e.eventData.pubkey == pubkey) {
      return true;
    }
    for( int i = 0; i < children.length; i++ ) {
      if( children[i].hasUserPost(pubkey)) {
        return true;
      }
    }
    return false;
  } 

  // returns true if the treee or its children has a post by user
  bool hasUserPostAndLike(String pubkey) {
    bool hasReacted = false;

    if( gReactions.containsKey(e.eventData.id))  {
      List<List<String>>? reactions = gReactions[e.eventData.id];
      if( reactions  != null) {
        for( int i = 0; i < reactions.length; i++) {
          if( reactions[i][0] == pubkey) {
            hasReacted = true;
            break;
          }
        }
      }
    }

    if( e.eventData.pubkey == pubkey || hasReacted ) {
      return true;
    }
    for( int i = 0; i < children.length; i++ ) {
      if( children[i].hasUserPost(pubkey)) {
        return true;
      }
    }
    return false;
  } 


  // returns true if the given words exists in it or its children
  bool hasWords(String word) {
    //if(gDebug > 0) print("In tree selector hasWords: this id = ${e.eventData.id} word = $word");
    if( e.eventData.content.length > 1000) {
      return false;
    }

    if( e.eventData.content.toLowerCase().contains(word)) {
      return true;
    }
    for( int i = 0; i < children.length; i++ ) {
      //if(gDebug > 0) print("this id = ${e.eventData.id} word = $word i = $i ");
      
      // ignore too large comments
      if( children[i].e.eventData.content.length > 1000) {
        continue;
      }

      if( children[i].e.eventData.content.toLowerCase().contains(word)) {
        return true;
      }
    }
    return false;
  } 

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
        if( gDebug > 0) {
          print("latest pubkey : $latestContactEvent");
        }
        return allChildEventsMap[latestContactEvent]?.e;
      }

      return null;
  }
} // end Tree

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
  int aMostRecent = a.getMostRecent(0).e.eventData.createdAt;
  int bMostRecent = b.getMostRecent(0).e.eventData.createdAt;

  if(aMostRecent < bMostRecent) {
    return -1;
  } else {
    if( aMostRecent == bMostRecent) {
      return 0;
    }
  }
  return 1;
}

// for the given reaction event of kind 7, will update the global gReactions appropriately, returns 
// the reactedTo event's id, blank if invalid reaction etc
String processReaction(Event event) {
  if( event.eventData.kind == 7 && event.eventData.eTagsRest.isNotEmpty) {
    if(gDebug > 1) ("Got event of type 7");
    String reactorId  = event.eventData.pubkey;
    String comment    = event.eventData.content;
    int    lastEIndex = event.eventData.eTagsRest.length - 1;
    String reactedTo  = event.eventData.eTagsRest[lastEIndex];
    if( gReactions.containsKey(reactedTo)) {
      List<String> temp = [reactorId, comment];
      gReactions[reactedTo]?.add(temp);
    } else {
      List<List<String>> newReactorList = [];
      List<String> temp = [reactorId, comment];
      newReactorList.add(temp);
      gReactions[reactedTo] = newReactorList;
    }
    return reactedTo;
  }
  return "";
}

// will go over the list of events, and update the global gReactions appropriately
void processReactions(List<Event> events) {
  for (Event event in events) {
    processReaction(event);
  }
  return;
}

/*
 * @function getTree Creates a Tree out of these received List of events. 
 */
Tree getTree(List<Event> events) {
    if( events.isEmpty) {
      print("Warning: In printEventsAsTree: events length = 0");
      return Tree(Event("","",EventData("non","", 0, 0, "", [], [], [], [[]], {}), [""], "[json]"), [], {}, [], true);
    }

    // populate the global with display names which can be later used by Event print
    events.forEach( (x) => processKind0Event(x));

    // process NIP 25, or event reactions by adding them to a global map
    processReactions(events);

    // remove all events other than kind 0, 1, 3 and 7 
    events.removeWhere( (item) => !Tree.typesInEventMap.contains(item.eventData.kind));  

    // remove bot events
    events.removeWhere( (item) => gBots.contains(item.eventData.pubkey));

    // remove duplicate events
    Set ids = {};
    events.retainWhere((x) => ids.add(x.eventData.id));

    // translate and expand mentions for all
    events.forEach( (e) => e.eventData.translateAndExpandMentions());

    // create tree from events
    Tree node = Tree.fromEvents(events);

    if(gDebug != 0) print("total number of events in main tree = ${node.count()}");
    return node;
}

