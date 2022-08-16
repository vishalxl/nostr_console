import 'dart:io';
import 'package:nostr_console/event_ds.dart';

class Tree {
  Event             e;
  List<Tree>        children;
  Map<String, Tree> allEvents;
  Tree(this.e, this.children, this.allEvents);

  // @method create top level Tree from events. 
  // first create a map. then process each element in the map by adding it to its parent ( if its a child tree)
  factory Tree.fromEvents(List<Event> events) {
    if( events.isEmpty) {
      return Tree(Event("","",EventData("non","", 0, 0, "", [], [], [], [[]]), [""], "[json]"), [], {});
    }

    // create a map from list of events, key is eventId and value is event itself
    Map<String, Tree> mAllEvents = {};
    events.forEach((element) { mAllEvents[element.eventData.id] = Tree(element, [], {}); });

    mAllEvents.forEach((key, value) {

      if(value.e.eventData.eTagsRest.isNotEmpty ) {
        // is not a parent, find its parent and then add this element to that parent Tree
        //stdout.write("added to parent a child\n");
        String id = key;
        String parentId = value.e.eventData.getParent();
        mAllEvents[parentId]?.addChildNode(value);
      }
    });

    // add parent trees as top level child trees of this tree
    List<Tree>  topLevelTrees = [];
    for( var value in mAllEvents.values) {
        if( !value.e.eventData.eTagsRest.isNotEmpty) {  // if its a parent
            topLevelTrees.add(value);
        }
    }

    return Tree( events[0], topLevelTrees, mAllEvents); // TODO remove events[0]
  } // end fromEvents()

  bool insertEvents(List<Event> newEvents) {
    //print("In insertEvents num events: ${newEvents.length}");
    List<String> newEventsId = [];
    newEvents.forEach((element) { 
      if( allEvents[element.eventData.id] != null) {
        return; // don't process if the event is already present in the map
      }
      if( element.eventData.kind != 1) {
        return; // only kind 1 events are added to the tree
      }
      allEvents[element.eventData.id] = Tree(element, [], {}); 
      newEventsId.add(element.eventData.id);
    });

    //print("In insertEvents num eventsId: ${newEventsId.length}");
    newEventsId.forEach((newId) {

      Tree? t = allEvents[newId];
      if( t != null) {
        if( t.e.eventData.eTagsRest.isEmpty) {
          // is a parent event
            children.add(t);
        } else {
              String parentId = t.e.eventData.getParent();
              allEvents[parentId]?.addChildNode(t);
        }
      }
    });

    return true;
  }

  void addChild(Event child) {
    Tree node;
    node = Tree(child, [], {});
    children.add(node);
  }

  void addChildNode(Tree node) {
    children.add(node);
  }

  void printTree(int depth, bool onlyPrintChildren, var newerThan) {

    children.sort(ascendingTimeTree);
    if( !onlyPrintChildren) {
      e.printEvent(depth);
    } else {
      depth = depth - 1;
    }

    for( int i = 0; i < children.length; i++) {
      if(!onlyPrintChildren) {
        stdout.write("\n");  
        printDepth(depth+1);
        stdout.write("|\n");
      } else {

        DateTime dTime = DateTime.fromMillisecondsSinceEpoch(children[i].e.eventData.createdAt *1000);
        //print("comparing $newerThan with $dTime");
        if( dTime.compareTo(newerThan) < 0) {
          continue;
        }
        stdout.write("\n");  
        printDepth(depth+1);
        stdout.write("\n\n\n");
      }

      // if the thread becomes too 'deep' then reset its depth, so that its 
      // children will not be displayed too much the right, but are shifted
      // left by about <leftShiftDeepThreadsBy> places
      if( depth > max_depth_allowed) {
        depth = max_depth_allowed - leftShiftDeepThreadsBy;
        printDepth(depth+1);
        stdout.write("+-------------------------------+\n");
        
      }
      children[i].printTree(depth+1, false, newerThan);
    }
  }

  /*
   * @getTagsFromEvent Searches for all events, and creates a json of e-tag type which can be sent with event
   *                   Also adds 'client' tag with application name.
   * @parameter replyToId First few letters of an event id for which reply is being made
   */
  String getTagStr(String replyToId, String clientName) {
    String strTags = "";

    if( replyToId.isEmpty) {
      return strTags;
    }

    if( clientName.isEmpty) {
      clientName = "nostr_console";
    }

    int latestEventTime = 0;
    String latestEventId = "";
    for(  String k in allEvents.keys) {
      if( k.substring(0, replyToId.length) == replyToId) {
        if( ( allEvents[k]?.e.eventData.createdAt ?? 0) > latestEventTime ) {
          latestEventTime = allEvents[k]?.e.eventData.createdAt ?? 0;
          latestEventId = k;
        }
      }
    }
    
    print("latestEventId = $latestEventId");
    if( latestEventId.isNotEmpty) {
      strTags =  '["e","$latestEventId"]';
    }

    /*
    if( strTags != "") {
      strTags += ",";
    }

    strTags += '["client", "$clientName"]' ;
    */
    print(strTags);
    return strTags;
  }
 
}

int ascendingTimeTree(Tree a, Tree b) {
  if(a.e.eventData.createdAt < b.e.eventData.createdAt) {
    return 0;
  }
  return 1;
}


Tree getTree(events) {
    if( events.length == 0) {
      print("Warning: In printEventsAsTree: events length = 0");
      return Tree(Event("","",EventData("non","", 0, 0, "", [], [], [], [[]]), [""], "[json]"), [], {});
    }

    // populate the global with display names which can be later used by Event print
    events.forEach( (x) => processKind0Event(x));

    // remove all events other than kind 1 ( posts)
    events.removeWhere( (item) => item.eventData.kind != 1 );  

    // remove bot events
    events.removeWhere( (item) => gBots.contains(item.eventData.pubkey));

    // remove duplicate events
    Set ids = {};
    events.retainWhere((x) => ids.add(x.eventData.id));

    // create tree from events
    Tree node = Tree.fromEvents(events);

    return node;
}
