import 'dart:collection';
import 'dart:io';
import 'dart:convert';
import 'package:nostr_console/console_ui.dart';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:nostr_console/settings.dart';

typedef fTreeSelector = bool Function(Tree a);
typedef fRoomSelector = bool Function(ScrollableMessages room);

Store? gStore = null;

bool selectorShowAllTrees(Tree t) {
  return true;
}

bool selectorShowAllRooms(ScrollableMessages room) {
  return true;
}

bool showAllRooms (ScrollableMessages room) => selectorShowAllRooms(room);

int getLatestMessageTime(ScrollableMessages channel) {

  List<String> _messageIds = channel.messageIds;
  if(gStore == null) {
    return 0;
  }

  if(_messageIds.length == 0) {
    int createdAt = channel.createdAt;
    return createdAt;
  }

  int latest = 0;
  for(int i = 0; i < _messageIds.length; i++) {
    if( gStore != null) {
      Tree? tree = (gStore?.allChildEventsMap[_messageIds[i]]  );
      if( tree != null) {
        EventData ed = tree.event.eventData;
        if( ed.createdAt > latest) {
          latest = ed.createdAt;
        }
      }
    }
  }
  return latest;
}

Channel? getChannel(List<Channel> channels, String channelId) {
  for( int i = 0; i < channels.length; i++) {
    if( channels[i].channelId == channelId) {
      return channels[i];
    }
  }
  return null;
}


DirectMessageRoom? getDirectRoom(List<DirectMessageRoom> rooms, String otherPubkey) {
  for( int i = 0; i < rooms.length; i++) {
    if( rooms[i].otherPubkey == otherPubkey) {
      return rooms[i];
    }
  }
  return null;
}

int scrollableCompareTo(ScrollableMessages a, ScrollableMessages b) {

  if( gStore == null)
    return 0;

  int otherLatest = getLatestMessageTime(b);
  int thisLatest =  getLatestMessageTime(a);

  if( thisLatest < otherLatest) {
    return 1;
  } else {
    if( thisLatest == otherLatest) {
      return 0;
    } else {
      return -1;
    }
  }
}

class ScrollableMessages {
  String       topHeader;
  List<String> messageIds;
  int          createdAt;

  ScrollableMessages(this.topHeader, this.messageIds, this.createdAt);

  void addMessageToRoom(String messageId, Map<String, Tree> tempChildEventsMap) {
    int newEventTime = (tempChildEventsMap[messageId]?.event.eventData.createdAt??0);

    if(gDebug> 0) print("Room has ${messageIds.length} messages already. adding new one to it. ");

    for(int i = 0; i < messageIds.length; i++) {
      int eventTime = (tempChildEventsMap[messageIds[i]]?.event.eventData.createdAt??0);
      if( newEventTime < eventTime) {
        // shift current i and rest one to the right, and put event Time here
        if(gDebug> 0) print("In addMessageToRoom: inserted in middle to room ");
        messageIds.insert(i, messageId);
        return;
      }
    }
    if(gDebug> 0) print("In addMessageToRoom: added to room ");

    // insert at end
    messageIds.add(messageId);
    return;
  }



  void printOnePage(Map<String, Tree> tempChildEventsMap, [int page = 1])  {
    if( page < 1) {
      if( gDebug > 0) log.info("In ScrollableMessages::printOnepage  got page = $page");
      page = 1;
    }

    printCenteredHeadline(topHeader);

    int i = 0, startFrom = 0, endAt = messageIds.length;
    int numPages = 1;

    if( messageIds.length > gNumChannelMessagesToShow ) {
      endAt = messageIds.length - (page - 1) * gNumChannelMessagesToShow;
      if( endAt < gNumChannelMessagesToShow) endAt = gNumChannelMessagesToShow;
      startFrom = endAt - gNumChannelMessagesToShow;
      numPages = (messageIds.length ~/ gNumChannelMessagesToShow) + 1;
      if( page > numPages) {
        page = numPages;
      }
    }
    if( gDebug > 0) print("StartFrom $startFrom  endAt $endAt  numPages $numPages room.messageIds.length = ${messageIds.length}");
    for( i = startFrom; i < endAt; i++) {
      String eId = messageIds[i];
      Event? e = tempChildEventsMap[eId]?.event;
      if( e!= null) {
        if( !(e.eventData.kind == 142 && (e.eventData.content == e.eventData.evaluatedContent))) // condition so that in encrypted channels non-encrypted messages aren't printed
          print(e.eventData.getStrForChannel(0));
      }
    }

    if( messageIds.length > gNumChannelMessagesToShow) {
      print("\n");
      printDepth(0);
      stdout.write("${gNotificationColor}Displayed page number ${page} (out of total $numPages pages, where 1st is the latest 'page').\n");
      printDepth(0);
      stdout.write("To see older pages, enter numbers from 1-${numPages}.${gColorEndMarker}\n\n");
    }
  }

  bool selectorNotifications() {
    if( gStore == null)
      return false;

    for(int i = 0; i < messageIds.length; i++) {
      Event? e = gStore?.allChildEventsMap[messageIds[i]]?.event;
      if( e != null) {
        if( e.eventData.isNotification == true) {
          return true;
        }
      }
    }

    return false;
  }
}

class Channel extends ScrollableMessages {
  String       channelId; // id of the kind 40 start event
  String       internalChatRoomName; 
  String       about;
  String       picture;
  int          lastUpdated; // used for encryptedChannels
  

  Set<String> participants; // pubkey of all participants - only for encrypted channels
  String      creatorPubkey;      // creator of the channel, if event is known

  Channel(this.channelId, this.internalChatRoomName, this.about, this.picture, List<String> messageIds, this.participants, this.lastUpdated, [this.creatorPubkey=""]) : 
            super (  internalChatRoomName.isEmpty? channelId: internalChatRoomName + "( " + channelId + " )" , 
                     messageIds,
                     lastUpdated);

  String getChannelId() {
    return channelId;
  }

  String get chatRoomName {
    return internalChatRoomName;
  }

  void set chatRoomName(String newName){
    internalChatRoomName = newName;
    super.topHeader = newName + " (${channelId.substring(0,6)})";
  }

  // takes special consideration of kind 142 messages that may be added to chanenl but aren't actually valid cause they aren't encrypted
  int getNumValidMessages() {
    if( gStore == null) {
      return messageIds.length;
    }

    int numMessages = 0;
    for( int i = 0; i < messageIds.length; i++) {
      if( gStore != null) {
        int? kind = gStore?.allChildEventsMap[messageIds[i]]?.event.eventData.kind;
        Event? e = gStore?.allChildEventsMap[messageIds[i]]?.event;
        if( kind != null && e!= null) {
          if( kind == 142 && e.eventData.content == e.eventData.evaluatedContent) {
            continue;
          } else {
            numMessages++;
          }
        }
      }
    }

    return numMessages;
  }
 }

class DirectMessageRoom extends ScrollableMessages{
  String       otherPubkey; // id of user this DM is happening
  int          createdAt;

  DirectMessageRoom(this.otherPubkey, List<String> messageIds, this.createdAt):
            super ( "${getAuthorName(otherPubkey)} ($otherPubkey)", messageIds, createdAt) {
            }

  String getChannelId() {
    return otherPubkey;
  }


  bool isPrivateMessageRoom() {
    return false;
  }

  void printDirectMessageRoom(Store store, [int page = 1])  {
    if( page < 1) {
      if( gDebug > 0) log.info("In printChannel got page = $page");
      page = 1;
    }
    printOnePage(store.allChildEventsMap, page);
  }
 }



class Tree {
  Event          event;                   // is dummy for very top level tree. Holds an event otherwise.
  List<Tree>     children;            // only has kind 1 events
  Store?         store;

  Tree(this.event, this.children,this.store );
  factory Tree.withoutStore(Event e, List<Tree> c) {
    return Tree(e, c, null);
  }

  void setStore(Store s) {
    store = s;
  }

  /***********************************************************************************************************************************/
  /* The main print tree function. Calls the reeSelector() for every node and prints it( and its children), only if it returns true. 
   */
  int printTree(int depth, DateTime newerThan, bool topPost) {
    int numPrinted = 0;

    event.printEvent(depth, topPost);
    numPrinted++;

    bool leftShifted = false;
    for( int i = 0; i < children.length; i++) {

      // if the thread becomes too 'deep' then reset its depth, so that its 
      // children will not be displayed too much on the right, but are shifted
      // left by about <leftShiftThreadsBy> places
      if( depth > maxDepthAllowed) {
        depth = maxDepthAllowed - leftShiftThreadsBy;
        printDepth(depth+1);
        stdout.write("    ┌${getNumDashes((leftShiftThreadsBy + 1) * gSpacesPerDepth - 1, "─")}┘\n");        
        leftShifted = true;
      }

      numPrinted += children[i].printTree(depth+1, newerThan, false);
    }
    // https://gist.github.com/dsample/79a97f38bf956f37a0f99ace9df367b9
    if( leftShifted) {
      stdout.write("\n");
      printDepth(depth+1);
      print("    ┴"); // same spaces as when its left shifted
    }

    return numPrinted;
  }

  // returns the time of the most recent comment
  int getMostRecentTime(int mostRecentTime) {
    if( children.isEmpty)   {
      return event.eventData.createdAt;
    }
    if( event.eventData.createdAt > mostRecentTime) {
      mostRecentTime = event.eventData.createdAt;
    }

    int mostRecentIndex = -1;
    for( int i = 0; i < children.length; i++) {
      int mostRecentChild = children[i].getMostRecentTime(mostRecentTime);
      if( mostRecentTime <= mostRecentChild) {
        mostRecentTime = mostRecentChild;
        mostRecentIndex = i;
      }
    }
    if( mostRecentIndex == -1) { 
      Tree? top = store?.getTopTree(this);
      // typically this should not happen. child nodes/events can't be older than parents 
      return (top?.event.eventData.createdAt)??mostRecentTime;
    } else {
      return mostRecentTime;
    }
  }

  // returns true if the treee or its children has a reply or like for the user with public key pk; and notification flags are set for such events
  bool treeSelectorRepliesAndLikes(String pk) {
    bool hasReaction = false;
    bool childMatches = false;

    if( event.eventData.pubkey == pk &&  gReactions.containsKey(event.eventData.id)) {
      List<List<String>>? reactions = gReactions[event.eventData.id];
      if( reactions  != null) {
        if( reactions.length > 0) {
          // has reactions
          reactions.forEach((reaction) {  
            // dont add notificatoin for self reaction
            Event? reactorEvent = store?.allChildEventsMap[reaction[0]]?.event;
            if( reactorEvent != null) {
              if( reactorEvent.eventData.pubkey != pk){ // ignore self likes 
                event.eventData.newLikes.add(reaction[0]);
                hasReaction = true;
              }
            }
          });
        }
      }
    }

    if( event.eventData.pubkey == pk && children.length > 0) {
      for( int i = 0; i < children.length; i++ ) {
        children.forEach((child) {  
          // if child is someone else then set notifications and flag, means there are replies to this event 
          childMatches = child.event.eventData.isNotification =  ((child.event.eventData.pubkey != pk)? true: false) ; 
        }); 
      }
    }

    for( int i = 0; i < children.length; i++ ) {
      if( children[i].treeSelectorRepliesAndLikes(pk)) {
        childMatches = true;
      }
    }

    if( hasReaction || childMatches) {
      return true;
    }
    return false;
  } 


  // returns true if the treee or its children has a post or like by user; and notification flags are set for such events
  bool treeSelectorUserPostAndLike(String pubkey) {
    bool hasReacted = false;

    if( gReactions.containsKey(event.eventData.id))  {
      List<List<String>>? reactions = gReactions[event.eventData.id];
      if( reactions  != null) {
        for( int i = 0; i < reactions.length; i++) {
          if( reactions[i][0] == pubkey) {
            event.eventData.newLikes.add(pubkey);
            hasReacted = true;
            break;
          }
        }
      }
    }

    bool childMatches = false;
    for( int i = 0; i < children.length; i++ ) {
      if( children[i].treeSelectorUserPostAndLike(pubkey)) {
        childMatches = true;
      }
    }
    if( event.eventData.pubkey == pubkey) {
      event.eventData.isNotification = true;
      return true;
    }
    if( hasReacted || childMatches) {
      return true;
    }
    return false;
  } 

  // returns true if the given words exists in it or its children
  bool treeSelectorHasWords(String word) {
    if( event.eventData.content.length > 2000) { // ignore if content is too large, takes lot of time
      return false;
    }

    bool childMatches = false;
    for( int i = 0; i < children.length; i++ ) {
      // ignore too large comments
      if( children[i].event.eventData.content.length > 2000) {
        continue;
      }

      if( children[i].treeSelectorHasWords(word)) {
        childMatches = true;
      }
    }

    if( event.eventData.content.toLowerCase().contains(word) || event.eventData.id == word ) {
      event.eventData.isNotification = true;
      return true;
    }
    if( childMatches) {
      return true;
    }
    return false;
  } 

  // returns true if the event or any of its children were made from the given client, and they are marked for notification
  bool treeSelectorClientName(String clientName) {

    bool byClient = false;
    List<List<String>> tags = event.eventData.tags;
    for( int i = 0; i < tags.length; i++) {
      if( tags[i].length < 2) {
        continue;
      }
      if( tags[i][0] == "client" && tags[i][1].contains(clientName)) {
        event.eventData.isNotification = true;
        byClient = true;
        break;
      }
    }

    bool childMatch = false;
    for( int i = 0; i < children.length; i++ ) {
      if( children[i].treeSelectorClientName(clientName)) {
        childMatch = true;
      }
    }
    if( byClient || childMatch) {
      return true;
    }

    return false;
  } 

  // returns true if the event or any of its children were made from the given client, and they are marked for notification
  bool treeSelectorNotifications() {

    bool hasNotifications = false;
    if( event.eventData.isNotification || event.eventData.newLikes.length > 0) {
        hasNotifications = true;
    }

    bool childMatch = false;
    for( int i = 0; i < children.length; i++ ) {
      if( children[i].treeSelectorNotifications()) {
        childMatch = true;
        break;
      }
    }
    if( hasNotifications || childMatch) {
      return true;
    }

    return false;
  } 

  // counts all valid events in the tree: ignores the dummy nodes that are added for events which aren't yet known
  int count() {
    int totalCount = 0;

    if( event.eventData.pubkey != gDummyAccountPubkey) { // don't count dummy events
        totalCount = 1;
    }

    for(int i = 0; i < children.length; i++) {
      totalCount += children[i].count(); // then add all the children
    }

    return totalCount;
  }


} // end Tree

/***********************************************************************************************************************************/
/*  
 * The actual tree holds only kind 1 events, or only posts
 * This Store class holds events too in its map, and in its chatRooms structure
 */
class Store {
  List<Tree>        topPosts;            // only has kind 1 events

  Map<String, Tree>  allChildEventsMap;   // has events of kind typesInEventMap
  List<String>       eventsWithoutParent;

  List<Channel>   channels = [];
  List<Channel>   encryptedChannels = [];
  List<DirectMessageRoom> directRooms = [];

  static String startMarkerStr = "" ;
  static String endMarkerStr = "";

  static const Set<int>   typesInEventMap = {0, 1, 3, 4, 5, 7, 40, 42, 140, 141, 142}; // 0 meta, 1 post, 3 follows list, 7 reactions

  Store(this.topPosts, this.allChildEventsMap, this.eventsWithoutParent, this.channels, this.encryptedChannels, this.directRooms) {
    allChildEventsMap.forEach((eventId, tree) {
      if( tree.store == null) {
        tree.setStore(this);
      }
    });
    reCalculateMarkerStr();
  }

  static void reCalculateMarkerStr() {
    int depth = 0;
    Store.startMarkerStr = getDepthSpaces(depth);
    Store.startMarkerStr += ("▄────────────\n");  // bottom half ▄


    int endMarkerDepth = depth + 1 + gTextWidth~/ gSpacesPerDepth - 1;
    Store.endMarkerStr = getDepthSpaces(endMarkerDepth);
    Store.endMarkerStr += "█\n";
    Store.endMarkerStr +=  "────────────▀".padLeft((endMarkerDepth) * gSpacesPerDepth + gNumLeftMarginSpaces + 1) ;
    Store.endMarkerStr += "\n";
  }

  static void handleChannelEvents( List<Channel> rooms, Map<String, Tree> tempChildEventsMap, Event ce) {
      String eId = ce.eventData.id;
      int    eKind = ce.eventData.kind;

      switch(eKind) {
      case 42:
      {
        if( gCheckEventId == ce.eventData.id)          print("In handleChannelEvents: processing $gCheckEventId ");
        String channelId = ce.eventData.getChannelIdForMessage();
        if( channelId != "") { // sometimes people may forget to give e tags or give wrong tags like #e
          Channel? channel = getChannel(rooms, channelId);
          if( channel != null) {
            if( gDebug > 0) print("chat room already exists = $channelId adding event to it" );
            if( gCheckEventId == ce.eventData.id) print("Adding new message $eId to a chat room $channelId. ");
   
            channel.addMessageToRoom(eId, tempChildEventsMap);
    
          } else {
            Channel newChannel = Channel(channelId, "", "", "", [eId], {}, 0);
            rooms.add( newChannel);
          }
        }
      }
      break;
      case 40:
       {
        String chatRoomId = eId;
        try {
          dynamic json = jsonDecode(ce.eventData.content);
          Channel? channel = getChannel(rooms, chatRoomId);
          if( channel != null) {
            if( channel.chatRoomName == "" && json.containsKey('name')) {
              channel.chatRoomName = json['name'];
            }
          } else {
            String roomName = "", roomAbout = "";
            if(  json.containsKey('name') ) {
              roomName = json['name']??"";
            }
            
            if( json.containsKey('about')) {
              roomAbout = json['about'];
            }
            List<String> emptyMessageList = [];
            Channel room = Channel(chatRoomId, roomName, roomAbout, "", emptyMessageList, {}, ce.eventData.createdAt);
            //print("created room with id $chatRoomId");
            rooms.add( room);
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

  static void handleEncryptedChannelEvents( List<DirectMessageRoom> directRooms, List<Channel> encryptedChannels, Map<String, Tree> tempChildEventsMap, Event ce) {
      String eId = ce.eventData.id;
      int    eKind = ce.eventData.kind;

      switch(eKind) {
      case 142:
      {
        if( gCheckEventId == ce.eventData.id)          print("In handleEncryptedChannelEvents: processing $gCheckEventId ");
        String channelId = ce.eventData.getChannelIdForMessage();
        if( channelId != "") { // sometimes people may forget to give e tags or give wrong tags like #e
          Channel? channel = getChannel(encryptedChannels, channelId);

          if( channel != null) {
            if( gDebug > 0) print("encrypted chat room already exists = $channelId adding event to it" );
            if( gCheckEventId == ce.eventData.id) print("Adding new message $eId to a chat room $channelId. ");
   
            channel.addMessageToRoom(eId, tempChildEventsMap);
    
          } else {
            Channel newChannel = Channel(channelId, "", "", "", [eId], {}, 0);
            encryptedChannels.add( newChannel);
          }
        }
      }
      break;
      case 141:
      {
        Set<String> participants = {};
        ce.eventData.pTags.forEach((element) { participants.add(element);});
        
        if( ce.eventData.id == "21779b82caf3628c83f382ad45a78ca0958e5edae7643d3fb222c03732c299d0") {
          //printInColor("handling 141 : 21779b82caf3628c83f382ad45a78ca0958e5edae7643d3fb222c03732c299d0\n", redColor);
        }

        String chatRoomId = ce.eventData.getChannelIdForMessage();
        //print("--------\nIn handleEncryptedChannelEvents: processing kind 141 id with ${ce.eventData.id} with participants = $participants");
        //print("for original channel id: $chatRoomId");
        try {
          dynamic json = jsonDecode(ce.eventData.content);
          Channel? channel = getChannel(encryptedChannels, chatRoomId);
          if( channel != null) {
            //print("got 141, and channel structure already exists");
            // as channel entry already exists, then update its participants info, and name info
            if( channel.chatRoomName == "" && json.containsKey('name')) {
              channel.chatRoomName = json['name'];
              //print("renamed channel to ${channel.chatRoomName}");
            }
            if( ce.eventData.id == "21779b82caf3628c83f382ad45a78ca0958e5edae7643d3fb222c03732c299d0") {
              //printInColor("original: ${channel.participants}\n new participants: $participants \n chatRoomId:${chatRoomId}", redColor);
            }

            if( channel.lastUpdated < ce.eventData.createdAt) {
              if( participants.contains(userPublicKey) && !channel.participants.contains(userPublicKey) ) {
                //printInColor("\nReceived new invite to a new group with id: $chatRoomId\n", greenColor);
              }

              channel.participants = participants;
              channel.lastUpdated  = ce.eventData.createdAt;
              for(int i = 0; i < channel.messageIds.length; i++) {
                Event ?e = tempChildEventsMap[channel.messageIds[i]]?.event;
                if( e != null) {
                  //print("num directRooms = ${directRooms.length}");
                  e.eventData.translateAndExpand14x(directRooms, encryptedChannels, tempChildEventsMap);
                }
              }
            }

          } else {
            //print("In handleEncryptedChannelEvents: got 141 when 140 is not yet found");
            String roomName = "", roomAbout = "";
            if(  json.containsKey('name') ) {
              roomName = json['name']??"";
            }
            
            if( json.containsKey('about')) {
              roomAbout = json['about'];
            }
            List<String> emptyMessageList = [];
            Channel room = Channel(chatRoomId, roomName, roomAbout, "", emptyMessageList, participants, ce.eventData.createdAt);
            //print("created encrypted room with id $chatRoomId and name $roomName");
            encryptedChannels.add( room);
          }
        } on Exception catch(e) {
          if( gDebug > 0) print("In From Event. Event type 140. Json Decode error for event id ${ce.eventData.id}. error = $e");
        }
      }
      break;

      case 140:
      {
        Set<String> participants = {};
        ce.eventData.pTags.forEach((element) { participants.add(element);});
        //print("In handleEncryptedChannelEvents: processing new en channel with participants = $participants");

        String chatRoomId = eId;
        try {
          dynamic json = jsonDecode(ce.eventData.content);
          Channel? channel = getChannel(encryptedChannels, chatRoomId);
          if( channel != null) {
            // if channel entry already exists, then update its participants info, and name info
            if( channel.chatRoomName == "" && json.containsKey('name')) {
              channel.chatRoomName = json['name'];
              //print("renamed channel to ${channel.chatRoomName}");
            }
            if( channel.lastUpdated == 0) { // ==  0 only when it was created using a 142 msg. otherwise, don't update it if it was created using 141
              channel.participants = participants;
              channel.lastUpdated  = ce.eventData.createdAt;
            }
            channel.creatorPubkey = ce.eventData.pubkey;

          } else {
            String roomName = "", roomAbout = "";
            if(  json.containsKey('name') ) {
              roomName = json['name']??"";
            }
            
            if( json.containsKey('about')) {
              roomAbout = json['about'];
            }
            List<String> emptyMessageList = [];
            Channel room = Channel(chatRoomId, roomName, roomAbout, "", emptyMessageList, participants, ce.eventData.createdAt, ce.eventData.pubkey);
            //print("created encrypted room with id $chatRoomId and name $roomName");
            encryptedChannels.add( room);
          }
        } on Exception catch(e) {
          if( gDebug > 0) print("In From Event. Event type 140. Json Decode error for event id ${ce.eventData.id}. error = $e");
        }
      }
      break;
      default:
      break;  
      } // end switch
  }


  static void handleDirectMessages( List<DirectMessageRoom> directRooms, Map<String, Tree> tempChildEventsMap, Event ce) {
      String eId = ce.eventData.id;
      int    eKind = ce.eventData.kind;

      if( ce.eventData.id == gCheckEventId) {
        printInColor("in handleDirectmessge: $gCheckEventId", redColor);
      }

      if( !isValidDirectMessage(ce.eventData)) {
        if( ce.eventData.id == gCheckEventId) {
          printInColor("in handleDirectmessge: returning", redColor);
        }
        return;
      }

      switch(eKind) {
      case 4:
      {
        String directRoomId = getDirectRoomId(ce.eventData);
        if( directRoomId != "") {

          bool alreadyExists = false;

          int i = 0;
          for(i = 0; i < directRooms.length; i++) {
            if ( directRoomId == directRooms[i].otherPubkey) {
              alreadyExists = true;
              break;
            }
          }

          if( alreadyExists) {
            if( ce.eventData.id == gCheckEventId && gDebug >= 0) print("Adding new message ${ce.eventData.id} to a direct room $directRoomId sender pubkey = ${ce.eventData.pubkey}. ");
            directRooms[i].addMessageToRoom( eId, tempChildEventsMap);
          } else {
            List<String> temp = [];
            temp.add(eId);
            DirectMessageRoom newDirectRoom= DirectMessageRoom(directRoomId,  temp, ce.eventData.createdAt);
            directRooms.add( newDirectRoom);
            if( ce.eventData.id == gCheckEventId && gDebug >= 0) print("Adding new message ${ce.eventData.id} to NEW direct room $directRoomId.  sender pubkey = ${ce.eventData.pubkey}.");
          }
          ce.eventData.translateAndExpandMentions(directRooms, tempChildEventsMap);
        } else {
          if( gDebug > 0) print("Could not get chat room id for event ${ce.eventData.id}  sender pubkey = ${ce.eventData.pubkey}.");
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
  factory Store.fromEvents(Set<Event> events) {
    if( events.isEmpty) {
    List<DirectMessageRoom> temp = [];

      return Store( [], {}, [], [], [], temp);
    }

    // create a map tempChildEventsMap from list of events, key is eventId and value is event itself
    Map<String, Tree> tempChildEventsMap = {};
    events.forEach((event) { 
      // only add in map those kinds that are supported or supposed to be added ( 0 1 3 7 40)
      if( typesInEventMap.contains(event.eventData.kind)) {
        tempChildEventsMap[event.eventData.id] = Tree.withoutStore( event, []); 
      }
    });

    processDeleteEvents(tempChildEventsMap); // handle returned values perhaps later
    processReactions(events, tempChildEventsMap);

    // once tempChildEventsMap has been created, create connections between them so we get a tree structure from all these events.
    List<Tree>  topLevelTrees = [];// this will become the children of the main top node. These are events without parents, which are printed at top.
    List<String> tempWithoutParent = [];
    List<Channel> channels = [];
    List<Channel> encryptedChannels = [];
    List<DirectMessageRoom> tempDirectRooms = [];
    Set<String> dummyEventIds = {};

    int numEventsNotPosts = 0; // just for debugging info
    int numKind40Events   = 0;
    int numKind42Events   = 0;
    if( gDebug > 0) print("In Tree from Events: after adding all required events of type ${typesInEventMap} to tempChildEventsMap map, its size = ${tempChildEventsMap.length} ");

    tempChildEventsMap.forEach((newEventId, tree) {
      int eKind = tree.event.eventData.kind;

      // these are handled in another iteration ( cause first private messages need to be populated)
      if( eKind == 142 || eKind == 140 || eKind == 141) {
        return;
      }


      if( eKind == 42 || eKind == 40) {
        handleChannelEvents(channels, tempChildEventsMap, tree.event);
      }



      if( eKind == 4) {
        handleDirectMessages(tempDirectRooms, tempChildEventsMap, tree.event);
      }

      // only posts, of kind 1, are added to the main tree structure
      if( eKind != 1) {
        numEventsNotPosts++;
        return;
      }

      if( tree.event.eventData.id == gCheckEventId) {
        print("In fromEvent: got evnet id $gCheckEventId");
      }

      if(tree.event.eventData.eTags.isNotEmpty ) {
        // is not a parent, find its parent and then add this element to that parent Tree
        String parentId = tree.event.eventData.getParent(tempChildEventsMap);

        if( tree.event.eventData.id == gCheckEventId) {
          if(gDebug >= 0) print("In Tree FromEvents: e tag not empty. its parent id = $parentId  for id: $gCheckEventId");
        }

        if(tempChildEventsMap.containsKey( parentId)) {
          // if parent is in store
          if( tree.event.eventData.id == gCheckEventId) {
            if(gDebug >= 0) print("In Tree FromEvents: found its parent $parentId : for id: $gCheckEventId");
          }

          if( tempChildEventsMap[parentId]?.event.eventData.kind != 1) { // since parent can only be a kind 1 event
            if( gDebug > 1) log.info("In Tree.fromEvents: Not adding: got a kind 1 event whose parent is not a type 1 post: $newEventId . parent kind: ${tempChildEventsMap[parentId]?.event.eventData.kind}");
            return;
          }
            
    
          tempChildEventsMap[parentId]?.children.add(tree); 
        } else {
          // in case the parent is not in store
          if( tree.event.eventData.id == gCheckEventId) {
            if(gDebug >= 0) print("In Tree FromEvents: parent not found : for id: $gCheckEventId");
          }

          // in case where the parent of the new event is not in the pool of all events, 
          // then we create a dummy event and put it at top ( or make this a top event?) TODO handle so that this can be replied to, and is fetched
          Event dummy = Event("","",  EventData(parentId,gDummyAccountPubkey, tree.event.eventData.createdAt, 1, "Event not loaded", [], [], [], [[]], {}), [""], "[json]");

          Tree dummyTopNode = Tree.withoutStore(dummy, []);
          dummyTopNode.children.add(tree);
          tempWithoutParent.add(tree.event.eventData.id); 

          if( parentId.length == 64) {
            dummyEventIds.add(parentId);
          }
          else {
            if( gDebug > 0) {
              print("--------\ngot invalid parentId in fromEvents: $parentId");
              print("original json of event:\n${tree.event.originalJson}");
            }
          }
            
          // add the dummy evnets to top level trees, so that their real children get printed too with them
          // so no post is missed by reader
          topLevelTrees.add(dummyTopNode);
        }
      }
    }); // going over tempChildEventsMap and adding children to their parent's .children list

    tempChildEventsMap.forEach((newEventId, tree) {
      int eKind = tree.event.eventData.kind;
     if( eKind == 142 || eKind == 140 || eKind == 141) {
        handleEncryptedChannelEvents(tempDirectRooms, encryptedChannels, tempChildEventsMap, tree.event);
      }
    });

    // add parent trees as top level child trees of this tree
    for( var tree in tempChildEventsMap.values) {
      if( tree.event.eventData.kind == 1 &&  tree.event.eventData.eTags.isEmpty) {  // only posts which are parents
        topLevelTrees.add(tree);
      }
    }

    if(gDebug != 0) print("In Tree FromEvents: number of events in map which are not kind 1 = ${numEventsNotPosts}");
    if(gDebug != 0) print("In Tree FromEvents: number of events in map of kind 40 = ${numKind40Events}");
    if(gDebug != 0) print("In Tree FromEvents: number of events in map of kind 42 = ${numKind42Events}");
    if(gDebug != 0) print("In Tree FromEvents: number of events without parent in fromEvents = ${tempWithoutParent.length}");

    // get dummy events
    sendEventsRequest(gListRelayUrls1, dummyEventIds);

    // create a dummy top level tree and then create the main Tree object
    return Store( topLevelTrees, tempChildEventsMap, tempWithoutParent, channels, encryptedChannels, tempDirectRooms);
  } // end fromEvents()

   /***********************************************************************************************************************************/
   /* @processIncomingEvent inserts the relevant events into the tree and otherwise processes likes, delete events etc.
    *                        returns the id of the relevant ones actually inserted so that they can be printed as notifications. 
    */
  Set<String> processIncomingEvent(Set<Event> newEventsToProcess) {
    if( gDebug > 0) log.info("In insertEvetnts: allChildEventsMap size = ${allChildEventsMap.length}, called for ${newEventsToProcess.length} NEW events");

    Set<String> newEventIdsSet = {};

    Set<String> dummyEventIds = {};

    // add the event to the main event store thats allChildEventsMap
    newEventsToProcess.forEach((newEvent) { 
      
      if( allChildEventsMap.containsKey(newEvent.eventData.id)) {// don't process if the event is already present in the map
        return;
      }

      //ignore bots
      if( [4, 42, 142].contains( newEvent.eventData.kind ) && gBots.contains(newEvent.eventData.pubkey)) {
        return;
      }

      // handle reaction events and return if we could not find the reacted to. Continue otherwise to add this to notification set newEventIdsSet
      if( newEvent.eventData.kind == 7) {
        if( processReaction(newEvent, allChildEventsMap) == "") {
          if(gDebug > 0) print("In insertEvents: For new reaction ${newEvent.eventData.id} could not find reactedTo or reaction was already present by this reactor");
          return;
        }
      }

      // handle delete events. return if its not handled for some reason ( like deleted event not found)
      if( newEvent.eventData.kind == 5) {
        processDeleteEvent(allChildEventsMap, newEvent);
        if(gDebug > 0) print("In insertEvents: For new deleteion event ${newEvent.eventData.id} could not process it.");
        return;
      }

      if( newEvent.eventData.kind == 4) {
        if( !isValidDirectMessage(newEvent.eventData)) { // direct message not relevant to user are ignored; also otherwise validates the message that it has one p tag
          return;
        }
      }

      if( newEvent.eventData.kind == 0) {
        processKind0Event(newEvent);
      }

      // only kind 0, 1, 3, 4, 5( delete), 7, 40, 42, 140, 142 events are added to map-store, return otherwise
      if( !typesInEventMap.contains(newEvent.eventData.kind) ) {
        return;
      }

      // expand mentions ( and translate if flag is set) and then add event to main event map
      if( newEvent.eventData.kind != 142) 
        newEvent.eventData.translateAndExpandMentions(directRooms, allChildEventsMap); // this also handles dm decryption for kind 4 messages, for kind 1 will do translation/expansion; 

      // add them to the main store of the Tree object, but after checking that its not one of the dummy/missing events. 
      // In that case, replace the older dummy event, and only then add it to store-map
      // Dummy events are only added as top posts, so search there for them.
      bool isDummyReplacement = false;
      for(int i = 0; i < topPosts.length; i++) {
        Tree tree = topPosts[i];
        if( tree.event.eventData.id == newEvent.eventData.id) {
          // its a replacement. 
          if( gDebug > 0) log.info("In processIncoming: Replaced old dummy event of id: ${newEvent.eventData.id}");
          tree.event = newEvent;
          isDummyReplacement = true;
          tree = topPosts.removeAt(i);
          allChildEventsMap[tree.event.eventData.id] = tree;
          break;
        }
      }

      if( !isDummyReplacement)
        allChildEventsMap[newEvent.eventData.id] = Tree(newEvent, [], this);

      // add to new-notification list only if this is a recent event ( because relays may send old events, and we dont want to highlight stale messages)
      if( newEvent.eventData.createdAt > getSecondsDaysAgo(gDontHighlightEventsOlderThan)) {
        newEventIdsSet.add(newEvent.eventData.id);
      }
    });
    
    // now go over the newly inserted event, and add its to the tree for kind 1 events, add 42 events to channels. rest ( such as kind 0, kind 3, kind 7) are ignored.
    newEventIdsSet.forEach((newId) {
      Tree? newTree = allChildEventsMap[newId];
      if( newTree != null) {  // this should return true because we just inserted this event in the allEvents in block above

        switch(newTree.event.eventData.kind) {
          case 1:
            // only kind 1 events are added to the overall tree structure
            if( newTree.event.eventData.eTags.isEmpty) {
                // if its a new parent event, then add it to the main top parents ( this.children)
                topPosts.add(newTree);
            } else {
                // if it has a parent , then add the newTree as the parent's child
                String parentId = newTree.event.eventData.getParent(allChildEventsMap);
                if( allChildEventsMap.containsKey(parentId)) {
                  allChildEventsMap[parentId]?.children.add(newTree);
                } else {
                  // create top unknown parent and then add it
                  Event dummy = Event("","",  EventData(parentId, gDummyAccountPubkey, newTree.event.eventData.createdAt, 1, "Event not loaded", [], [], [], [[]], {}), [""], "[json]");
                  Tree dummyTopNode = Tree.withoutStore(dummy, []);
                  dummyTopNode.children.add(newTree);
                  topPosts.add(dummyTopNode);

                  // add it to list to fetch it from relays
                  if( parentId.length == 64)
                    dummyEventIds.add(parentId);                  
                }
            }
            break;
          case 4:
            // add kind 4 direct chat message event to its direct massage room
            String directRoomId = getDirectRoomId(newTree.event.eventData);

            if( directRoomId != "") {
              DirectMessageRoom? room = getDirectRoom(directRooms, directRoomId);
              if( room != null) {
                if( gDebug > 0) print("added event to direct room $directRoomId in insert event");
                room.addMessageToRoom(newTree.event.eventData.id, allChildEventsMap);
                newTree.event.eventData.isNotification = true; // highlight it too in next printing
                break;
              }
            }

            List<String> temp = [];
            temp.add(newTree.event.eventData.id);
            directRooms.add(DirectMessageRoom(directRoomId, temp, newTree.event.eventData.createdAt)); // TODO sort it 

            break;

          case 40:
            //print("calling handleChannelEvents for kind 40");
            handleChannelEvents(channels, allChildEventsMap, newTree.event);
            break;

          case 42:
            newTree.event.eventData.isNotification = true; // highlight it too in next printing
            // add 42 chat message event id to its chat room
            String channelId = newTree.event.eventData.getChannelIdForMessage();
            if( channelId != "") {
              Channel? channel = getChannel(channels, channelId);
              if( channel != null) {
                if( gDebug > 0) print("added event to chat room in insert event");
                channel.addMessageToRoom(newTree.event.eventData.id, allChildEventsMap); // adds in order
                break;
              } else {
                
                Channel newChannel = Channel(channelId, "", "", "", [], {}, 0);
                newChannel.addMessageToRoom(newTree.event.eventData.id, allChildEventsMap);
                channels.add(newChannel);
              }
            } 
            break;

          case 140:
          case 141:
            //print("calling handleEncryptedChannelEvents for kind ${newTree.event.eventData.kind} from processIncoming");
            handleEncryptedChannelEvents(directRooms, encryptedChannels, allChildEventsMap, newTree.event);
            break;

          case 142:
            
            newTree.event.eventData.isNotification = true; // highlight it too in next printing
            // add 142 chat message event id to its chat room
            String channelId = newTree.event.eventData.getChannelIdForMessage();
            if( channelId != "") {
              Channel? channel = getChannel(encryptedChannels, channelId);
              if( channel != null) {
                if( gDebug > 0) print("added event to encrypted chat room in insert event");
                channel.addMessageToRoom(newTree.event.eventData.id, allChildEventsMap); // adds in order
                newTree.event.eventData.translateAndExpand14x(directRooms, encryptedChannels, allChildEventsMap);
                break;
              } else {
                Set<String> participants = {};
                newTree.event.eventData.pTags.forEach((element) {participants.add(element);});
                Channel newChannel = Channel(channelId, "", "", "", [], participants, 0);
                newChannel.addMessageToRoom(newTree.event.eventData.id, allChildEventsMap);
                encryptedChannels.add(newChannel);
                newTree.event.eventData.translateAndExpand14x(directRooms, encryptedChannels, allChildEventsMap);
              }
            }
            
            break;


          default: 
            break;
        }
      }
    });

    // get dummy events
    sendEventsRequest(gListRelayUrls2, dummyEventIds);

    int totalTreeSize = 0;
    topPosts.forEach((element) {totalTreeSize += element.count();});
    if(gDebug > 0) print("In end of insertEvents: allChildEventsMap size = ${allChildEventsMap.length}; mainTree count = $totalTreeSize");
    if(gDebug > 0)  print("Returning ${newEventIdsSet.length} new notification-type events, which are ${newEventIdsSet.length < 10 ? newEventIdsSet: " <had more than 10 elements>"} ");
    return newEventIdsSet;
  } // end insertEvents()

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
      int k = (allChildEventsMap[newEventId]?.event.eventData.kind??-1);
      if( k == 7 || k == 1 || k == 42 || k == 40) {
        countNotificationEvents++;
      }

      if(  allChildEventsMap.containsKey(newEventId)) {
        if( gDebug > 0) print( "id = ${ (allChildEventsMap[newEventId]?.event.eventData.id??-1)}");
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
        switch(t.event.eventData.kind) {
          case 1:
            t.event.eventData.isNotification = true;
            Tree topTree = getTopTree(t);
            topNotificationTree.add(topTree);
            break;
          case 7:
            Event event = t.event;
            if(gDebug > 0) ("Got notification of type 7");
            String reactorId  = event.eventData.pubkey;
            int    lastEIndex = event.eventData.eTags.length - 1;
            String reactedTo  = event.eventData.eTags[lastEIndex];
            Event? reactedToEvent = allChildEventsMap[reactedTo]?.event;
            if( reactedToEvent != null) {
              Tree? reactedToTree = allChildEventsMap[reactedTo];
              if( reactedToTree != null) {
                if(event.eventData.content == "+" ) {
                  reactedToTree.event.eventData.newLikes.add( reactorId);
                  Tree topTree = getTopTree(reactedToTree);
                  topNotificationTree.add(topTree);
                } else if(event.eventData.content == "!" ) {
                  reactedToTree.event.eventData.isHidden = true;
                }
              } else {
                if(gDebug > 0) print("Could not find reactedTo tree");
              }
            } else {
              if(gDebug > 0) print("Could not find reactedTo event");
            }
            break;
          default:
            if(gDebug > 0) print("got an event thats not 1 or 7(reaction). its kind = ${t.event.eventData.kind} count17 = $countNotificationEvents");
            break;
        }
      }
    });

    // remove duplicate top trees
    Set ids = {};
    topNotificationTree.retainWhere((t) => ids.add(t.event.eventData.id));
    

    Store.reCalculateMarkerStr();

    topNotificationTree.forEach( (t) { 
      Store.printTopPost(t, 0, DateTime(0));
      //t.printTree(0, DateTime(0), true); 
      print("\n");
    });
    print("\n");
  }

  static int printTopPost(Tree topTree, int depth, DateTime newerThan) {
    stdout.write(Store.startMarkerStr);
    int numPrinted = topTree.printTree(depth, newerThan, true);
    stdout.write(endMarkerStr);
    return numPrinted;
  }

   /***********************************************************************************************************************************/
  /* The main print tree function. Calls the reeSelector() for every node and prints it( and its children), only if it returns true. 
   */
  int printTree(int depth, DateTime newerThan, fTreeSelector treeSelector) {

    int numPrinted = 0;

    topPosts.sort(sortTreeNewestReply); // sorting done only for top most threads. Lower threads aren't sorted so save cpu etc TODO improve top sorting


    // https://gist.github.com/dsample/79a97f38bf956f37a0f99ace9df367b9
    // bottom half ▄

    // |                             |         |                           |                          | 
    // screen start S0               S1        Sd                           S2                          S3
    //                  
    // gNumLeftMarginSpaces = S1 
    // gTextWidth = S2 - S1 
    // comment starts at Sd , then depth = Sd - S1 / gSpacesPerDepth
    // Depth is in gSpacesPerDepth 

    for( int i = 0; i < topPosts.length; i++) {
      // continue if this children isn't going to get printed anyway; selector is only called for top most tree
      if( treeSelector(topPosts[i]) == false) {
        continue;
      } 

      // for top Store, only print the thread that are newer than the given parameter
      int newestChildTime = topPosts[i].getMostRecentTime(0);
      DateTime dTime = DateTime.fromMillisecondsSinceEpoch(newestChildTime *1000);
      if( dTime.compareTo(newerThan) < 0) {
        continue;
      }

      for( int i = 0; i < gapBetweenTopTrees; i++ )  { 
        stdout.write("\n"); 
      }

      numPrinted += printTopPost(topPosts[i], depth, newerThan);
    }

    if( numPrinted > 0)
      print("\n\nTotal posts/replies printed: $numPrinted for last $gNumLastDays days");
    return numPrinted;
  }
 
  int getNumChannels() {
    return channels.length;
  }

  Channel? getChannelFromId(List<Channel> chs, String channelId) {
    for( int i = 0; i < chs.length; i++) {
      if( chs[i].channelId == channelId) {
        return chs[i];
      }
    }
    return null;
  }


  String getChannelNameFromId(List<Channel> chs, String channelId) {
    for( int i = 0; i < chs.length; i++) {
      if( chs[i].channelId == channelId) {
        return chs[i].chatRoomName;
      }
    }
    return "";
  }

  int getNumMessagesInChannel(String channelId) {
    for( int i = 0; i < channels.length; i++) {
      if( channels[i].channelId == channelId) {
        return channels[i].messageIds.length;
      }
    }
    return 0;
  }

  /**
   * @printAllChennelsInfo Print one line information about all channels, which are type 40 events ( class ChatRoom)
   */
  int printChannelsOverview(List<Channel> channelstoPrint, int numToPrint, fRoomSelector selector) {


    int numRoomsSelected = 0;
    for( int j = 0; j < channelstoPrint.length; j++) {
      //print(channelstoPrint[j].participants);
      if( channelstoPrint[j].participants.length == 0 || (channelstoPrint[j].participants.length > 0 &&  channelstoPrint[j].participants.contains(userPublicKey))) {
        if( selector(channelstoPrint[j]) ) {
          numRoomsSelected++;
        }
      } 
    }
    //print(numRoomsSelected);

    if( numRoomsSelected == 0) {
      return 0;
    }

    // if selected rooms is less, then print only that
    //if( numRoomsSelected < numToPrint)   numToPrint = numRoomsSelected;

    int numChannelsActuallyPrinted = 0;
    channelstoPrint.sort(scrollableCompareTo);
    print("");
    if( numToPrint < channelstoPrint.length) {
      print("Showing only $numToPrint/${channelstoPrint.length} total channels\n");
    } else {
      print("Showing all ${channelstoPrint.length} channels\n");
      numToPrint = channelstoPrint.length;
    }

    printUnderlined("      Channel Name                Num of Messages            Latest Message           ");
    for(int j = 0; j < numToPrint; j++) {

      if( channelstoPrint[j].participants.length > 0 &&  !channelstoPrint[j].participants.contains(userPublicKey)) {
        //print(channelstoPrint[j].participants);
        continue;
      }

      String name = "";
      if( channelstoPrint[j].chatRoomName == "") {
        //print("channel has no name");
        name = channelstoPrint[j].channelId.substring(0, 6);
      } else {
        name = "${channelstoPrint[j].chatRoomName} ( ${channelstoPrint[j].channelId.substring(0, 6)})";
      }

      int numMessages = channelstoPrint[j].getNumValidMessages();
      stdout.write("${name} ${getNumSpaces(32-name.length)}          $numMessages${getNumSpaces(12- numMessages.toString().length)}"); 
      numChannelsActuallyPrinted ++;
      List<String> messageIds = channelstoPrint[j].messageIds;
      for( int i = messageIds.length - 1; i >= 0; i--) {
        if( allChildEventsMap.containsKey(messageIds[i])) {
          Event? e = allChildEventsMap[messageIds[i]]?.event;
          if( e!= null) {
            if( !(e.eventData.kind == 142 && e.eventData.content == e.eventData.evaluatedContent)) {
              stdout.write("${e.eventData.getAsLine()}");
              break; // print only one event, the latest one
            }
          }
        }
      }
      print("");
    }
    return numChannelsActuallyPrinted;
  }

  void printChannel(Channel room, [int page = 1])  {
    if( page < 1) {
      if( gDebug > 0) log.info("In printChannel got page = $page");
      page = 1;
    }

    room.printOnePage(allChildEventsMap, page);
  }

  // prints some info about the encrypted channel
  void printEncryptedChannelInfo(Channel room) {
    // write owner
    String creator = room.creatorPubkey;
    print("\n\n");
    stdout.write("Encrypted channel creator: ");
    printInColor(getAuthorName(creator), gCommentColor);

    // write participants 
    stdout.write("\nChannel participants:      ");
    
    int i = 0;
    room.participants.forEach((participant) {
      
      if( i != 0) {
        stdout.write(', ');
      }
      String pName = getAuthorName(participant);
      printInColor("$pName", gCommentColor);
      i++;
    });

  }

  // shows the given channelId, where channelId is prefix-id or channel name as mentioned in room.name. returns full id of channel.
  // looks for channelId in id first, then in names. 
  String showChannel(List<Channel> listChannels, String channelId, [int page = 1]) {
    if( channelId.length > 64 ) {
      return "";
    }

    
    // first check channelsId's, in case user has sent a channelId itself
    Set<String> fullChannelId = {};
    for(int i = 0; i < listChannels.length; i++) {
      if( listChannels[i].channelId.substring(0, channelId.length) == channelId ) {
        fullChannelId.add(listChannels[i].channelId);
      }
    }

    if(fullChannelId.length != 1) {
      // lookup in channel room name
      for(int i = 0; i < listChannels.length; i++) {
          Channel room = listChannels[i];
          if( room.chatRoomName.length < channelId.length) {
            continue;
          }
          if( room.chatRoomName.substring(0, channelId.length) == channelId ) {
            fullChannelId.add(room.channelId);
          }
      } // end for
    }

    if( fullChannelId.length == 1) {
      Channel? room = getChannel( listChannels, fullChannelId.first);
      if( room != null) {

        if( room.participants.length > 0) {
          // enforce the participants-only rule
          if( !room.participants.contains(userPublicKey)) {
            print("\nnot a user: ${room.participants}");
            print("room name: ${room.chatRoomName}");
            return "";
          }


          printEncryptedChannelInfo(room);

          
          stdout.write("\n\n");
        }
        printChannel(room, page);
      }
      return fullChannelId.first;
    } else {
      if( fullChannelId.length == 0) {
        print("Could not find the channel.");
      }
      else {
        print("Found more than 1 channel: $fullChannelId");
      }
    }

    return "";
  }

  int getNumDirectRooms() {
    return directRooms.length;
  }

  /**
   * @printDirectRoomInfo Print one line information about chat rooms
   */
  int printDirectRoomInfo(fRoomSelector roomSelector) { 
    directRooms.sort(scrollableCompareTo);

    int numNotificationRooms = 0;
    for( int j = 0; j < directRooms.length; j++) {
      if( roomSelector(directRooms[j]))
        numNotificationRooms++;
    }

    // even if num rooms is zero, we will show the heading when its show all rooms
    if( numNotificationRooms == 0 && roomSelector != showAllRooms) { 
      return 0;
    }

    int numRoomsActuallyPrinted = 0;
    stdout.write("\n");
    stdout.write("Direct messages inbox:\n");
    stdout.write("\n\n");
    
    printUnderlined(" From                                    Num of Messages          Latest Message           ");
    for( int j = 0; j < directRooms.length; j++) {
      if( !roomSelector(directRooms[j]))
        continue;
      DirectMessageRoom room = directRooms[j];
      String name = getAuthorName(room.otherPubkey, 4);

      int numMessages = room.messageIds.length;
      stdout.write("${name} ${getNumSpaces(32-name.length)}          $numMessages${getNumSpaces(12- numMessages.toString().length)}"); 

      // print latest event in one line
      List<String> messageIds = room.messageIds;
      for( int i = messageIds.length - 1; i >= 0; i++) {
        if( allChildEventsMap.containsKey(messageIds[i])) {
          numRoomsActuallyPrinted++;
          Event? e = allChildEventsMap[messageIds[i]]?.event;
          if( e!= null) {
            String line = e.eventData.getAsLine();
            stdout.write(line);
            break; // print only one event, the latest one
          }
        }
      }
      stdout.write("\n");
    }

    return numRoomsActuallyPrinted;
  }

  // shows the given directRoomId, where directRoomId is prefix-id or pubkey of the other user. returns full id of other user.
  String showDirectRoom( String directRoomId, [int page = 1]) {
    if( directRoomId.length > 64) { // TODO revisit  cause if name is > 64 should not return
      return "";
    }
    Set<String> lookedUpName = {};

    // TODO improve lookup logic. 
    for( int j = 0; j < directRooms.length; j++) {
      String roomId = directRooms[j].otherPubkey;
      if( directRoomId == roomId) {
        lookedUpName.add(roomId);
      }

      if( directRooms[j].otherPubkey.substring(0, directRoomId.length) == directRoomId){
        lookedUpName.add(roomId);
      }

      if( getAuthorName( directRooms[j].otherPubkey).trim() == directRoomId){
        lookedUpName.add(roomId);
      }
    }

   
    if( lookedUpName.length == 1) {
      DirectMessageRoom? room =  getDirectRoom(directRooms, lookedUpName.first);
      if( room != null) {// room is already created, use it
        room.printDirectMessageRoom(this, page);
        return lookedUpName.first;
      } else {
        if( isValidPubkey(lookedUpName.first)) { // in case the pubkey is valid and we have seen the pubkey in global author list, create new room
          print("Could not find a conversation or room with the given id. Creating one with ${lookedUpName.first}");
          DirectMessageRoom room = createDirectRoom( directRoomId);
          room.printDirectMessageRoom(this, page);
          return directRoomId;
        }
      }
    } else {
      if( lookedUpName.length > 0) {
       print("Got more than one public id for the name given, which are: ${lookedUpName.length}");
      }
      else { // in case the given id is not present in our global list of usernames, create new room for them 
        if( isValidPubkey(directRoomId)) {
          print("Could not find a conversation or room with the given id. Creating one with $directRoomId");
          DirectMessageRoom room = createDirectRoom(directRoomId);
          room.printDirectMessageRoom(this, page);
          return directRoomId;
        } 
      }
      return "";
    }
    return "";
  }

  DirectMessageRoom createDirectRoom(String directRoomId) {
      int    createdAt = DateTime.now().millisecondsSinceEpoch ~/1000;
      DirectMessageRoom room = DirectMessageRoom(directRoomId, [], createdAt);
      directRooms.add(room); 
      return room;
  }

  // Write the tree's events to file as one event's json per line
  Future<void> writeEventsToFile(String filename) async {
    if( gDebug > 0) print("opening $filename to write to.");
    try {
      final File file         = File(filename);
      
      if( gOverWriteFile) {
        await  file.writeAsString("", mode: FileMode.write).then( (file) => file);
      }

      //await  file.writeAsString("", mode: FileMode.append).then( (file) => file);
      int        eventCounter = 0;
      String     nLinesStr    = "";
      int        countPosts   = 0;

      const int  numLinesTogether = 100; // number of lines to write in one write call
      int        linesWritten = 0;
      for( var tree in allChildEventsMap.values) {

        if( tree.event.eventData.isDeleted) { // dont write those deleted
          //continue; 
        }

        if( gOverWriteFile == false) {
          if( tree.event.readFromFile) { // ignore those already in file; only the new ones are writen/appended to file
            continue;
          }
        }

        // only write if its not too old
        if( gDontWriteOldEvents) {
          if( tree.event.eventData.createdAt <  getSecondsDaysAgo(gDontSaveBeforeDays)) {
            continue;
          }
        }

        if( gDummyAccountPubkey == tree.event.eventData.pubkey) {
          print("not writing dummy event pubkey");
          continue; // dont write dummy events
        }

        String line = "${tree.event.originalJson}\n";
        nLinesStr += line;
        eventCounter++;
        if( tree.event.eventData.kind == 1) {
          countPosts++;
        }

        if( eventCounter % numLinesTogether == 0) {
          await  file.writeAsString(nLinesStr, mode: FileMode.append).then( (file) => file);
          nLinesStr = "";
          linesWritten += numLinesTogether;
        }
      } // end for

      if(  eventCounter > linesWritten) {
        await  file.writeAsString(nLinesStr, mode: FileMode.append).then( (file) => file);
        nLinesStr = "";
      }

      if(gDebug > 0) log.info("finished writing eventCounter = ${eventCounter}.");
      print("Appended $eventCounter new events to file \"$gEventsFilename\" of which ${countPosts} are posts.");
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
  String getTagStr(String replyToId, String clientName, [bool addAllP = false]) {
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

        if( ( allChildEventsMap[k]?.event.eventData.createdAt ?? 0) > latestEventTime ) {
          latestEventTime = allChildEventsMap[k]?.event.eventData.createdAt ?? 0;
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
      String? pTagPubkey = allChildEventsMap[latestEventId]?.event.eventData.pubkey;
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
        rootEventId = topTree.event.eventData.id;
        if( rootEventId != latestEventId) { // if the reply is to a top/parent event, then only one e tag is sufficient
          strTags +=  '["e","$rootEventId","","root"],';
        }
      }
      strTags +=  '["e","$latestEventId","$relay","reply"],';
    }

    strTags += '["client","$clientName"]' ;
    return strTags;
  }

  // for any tree node, returns its top most parent
  Tree getTopTree(Tree tree) {
    while( true) {
      Tree? parent =  allChildEventsMap[ tree.event.eventData.getParent(allChildEventsMap)];
      if( parent != null) {
        tree = parent;
      } else {
        break;
      }
    }
    return tree;
  }

  // get followers of given pubkey 
  List<String> getFollowers(String pubkey) {
    if( gDebug > 0) print("Finding followrs for $pubkey");
    List<String> followers = [];

    gKindONames.forEach((otherPubkey, userInfo) { 
        List<Contact>? contactList = userInfo.latestContactEvent?.eventData.contactList;
        if( contactList != null ) {
          for(int i = 0; i < contactList.length; i ++) {
            if( contactList[i].id == pubkey) {
              followers.add(otherPubkey);
              return;
            }
          }
        }
    });

    return followers;
  }

  // finds all your followers, and then finds which of them follow the otherPubkey
  void printSocialDistance(Event contactEvent, String otherName) {
    String otherPubkey = contactEvent.eventData.pubkey;
    String otherName = getAuthorName(otherPubkey);


    bool isFollow = false;
    int  numSecond = 0; // number of your follows who follow the other

    List<String> mutualFollows = []; // displayed only if user is checking thier own profile
    int selfNumContacts =  0;

    Event? selfContactEvent = getContactEvent(userPublicKey);

    if( selfContactEvent != null) {
      List<Contact> selfContacts = selfContactEvent.eventData.contactList;
      selfNumContacts = selfContacts.length;
      for(int i = 0; i < selfContacts.length; i ++) {
        // check if you follow the other account
        if( selfContacts[i].id == otherPubkey) {
          isFollow = true;
        }
        // count the number of your contacts who know or follow the other account
        List<Contact> followContactList = [];
        Event? followContactEvent = getContactEvent(selfContacts[i].id);
        if( followContactEvent != null) {
          followContactList = followContactEvent.eventData.contactList;
          for(int j = 0; j < followContactList.length; j++) {
            if( followContactList[j].id == otherPubkey) {
              mutualFollows.add(getAuthorName(selfContacts[i].id));
              numSecond++;
              break;
            }
          }
        }
      }// end for loop through users contacts

      //print("");
      if( otherPubkey != userPublicKey) {

        if( isFollow) {
          print("* You follow $otherName ");
        } else {
          print("* You don't follow $otherName");
        }

        stdout.write("* Of the $selfNumContacts people you follow, $numSecond follow $otherName.");
      } else {
        stdout.write("* Of the $selfNumContacts people you follow, $numSecond follow you back. Their names are: ");
        mutualFollows.forEach((name) { stdout.write("$name, ");});
      }
      print("");
    } else {  // end if contact event was found
        print("* Note: Could not find your contact list");
    }
  }

  int count() {
    int totalEvents = 0;
    for(int i = 0; i < topPosts.length; i++) {
      totalEvents += topPosts[i].count(); // calling tree's count.
    }
    return totalEvents;
  }

  static List<String> processDeleteEvent(Map<String, Tree> tempChildEventsMap, Event deleterEvent) {
    List<String> deletedEventIds = [];
    if( deleterEvent.eventData.kind == 5) {
      deleterEvent.eventData.tags.forEach((tag) { 
        if( tag.length < 2) {
          return;
        }
        if( tag[0] == "e") {
          String deletedEventId = tag[1];
          // look up that event and ensure its kind 1 etc, and then mark it deleted.
          Event? deletedEvent = tempChildEventsMap[deletedEventId]?.event;
          if( deletedEvent != null) {
            if( (deletedEvent.eventData.kind == 1 || deletedEvent.eventData.kind == 42) && deletedEvent.eventData.pubkey == deleterEvent.eventData.pubkey) {
              deletedEvent.eventData.isDeleted = true;
              deletedEvent.eventData.content = gDeletedEventMessage;
              deletedEvent.eventData.evaluatedContent = "";
              EventData ed = deletedEvent.eventData;
              deletedEvent.originalJson = '["EVENT","deleted",{"id":"${ed.id}","pubkey":"${ed.pubkey}","created_at":${ed.createdAt},"kind":1,"tags":[],"sig":"deleted","content":"deleted"}]';
              deletedEventIds.add( deletedEvent.eventData.id);
            }          
          }
        }
      });
    } // end if
    return deletedEventIds;
  } // end processDeleteEvent

  static List<String> processDeleteEvents(Map<String, Tree> tempChildEventsMap) {
    List<String> deletedEventIds = [];
    tempChildEventsMap.forEach((key, tree) {
      Event deleterEvent = tree.event;
      if( deleterEvent.eventData.kind == 5) {
          List<String> tempIds = processDeleteEvent(tempChildEventsMap, deleterEvent);
          tempIds.forEach((tempId) { deletedEventIds.add(tempId); });
      }
    });
    return deletedEventIds;
  } // end processDeleteEvents

  Set<String> getEventEidFromPrefix(String eventId) {
    if( eventId.length > 64) {
      return {};
    }
    
    Set<String> foundEventIds = {};
    for(  String k in allChildEventsMap.keys) {
      if( k.length >= eventId.length && k.substring(0, eventId.length) == eventId) {
        foundEventIds.add(k);
      }
    }

    return foundEventIds;
  }

  // for the given reaction event of kind 7, will update the global gReactions appropriately, returns 
  // the reactedTo event's id, blank if invalid reaction etc
  static String processReaction(Event event, Map<String, Tree> tempChildEventsMap) {

    if(  gDebug > 0 && event.eventData.id == gCheckEventId)
        print("in processReaction: 0 got reaction $gCheckEventId");

    List<String> validReactionList = ["+", "!"]; // TODO support opposite reactions 
    List<String> opppositeReactions = ['-', "~"];

    if( event.eventData.content == "" ) { // cause damus sends blank reactions
      event.eventData.content = "+";
    }

    if( event.eventData.kind == 7 
      && event.eventData.eTags.isNotEmpty) {

      if(gDebug > 1) ("Got event of type 7"); // this can be + or !, which means 'hide' event for me
      String reactorPubkey  = event.eventData.pubkey;
      String reactorId      = event.eventData.id;
      String comment    = event.eventData.content;
      int    lastEIndex = event.eventData.eTags.length - 1;
      String reactedToId  = event.eventData.eTags[lastEIndex];

      if( gDebug > 0 && event.eventData.id == gCheckEventId)print("in processReaction: 1 got reaction $gCheckEventId");

      if( !validReactionList.any((element) => element == comment)) {
        if(gDebug > 0 && event.eventData.id == gCheckEventId)          print("$gCheckEventId not valid");
        return "";
      }

      // check if the reaction already exists by this user
      if( gReactions.containsKey(reactedToId)) {
        for( int i = 0; i < ((gReactions[reactedToId]?.length)??0); i++) {
          List<String> oldReaction = (gReactions[reactedToId]?[i])??[];
          if( oldReaction.length == 2) {
            //valid reaction
            if(oldReaction[0] == reactorPubkey && oldReaction[1] == comment) {

              if(gDebug > 0 && event.eventData.id == gCheckEventId) print("$gCheckEventId already got it");

              return ""; // reaction by this user already exists so return
            }
          }
        }
        List<String> temp = [reactorPubkey, comment];
        gReactions[reactedToId]?.add(temp);
        
        if(gDebug > 0 &&  event.eventData.id == gCheckEventId)  print("$gCheckEventId milestone 3");
        
        if( event.eventData.isNotification) {
          // if the reaction is new ( a notification) then the comment it is reacting to also becomes a notification in form of newLikes

          if( gDebug > 0 && event.eventData.id == gCheckEventId) print("milestone 2 for $gCheckEventId");

          tempChildEventsMap[reactedToId]?.event.eventData.newLikes.add(reactorPubkey);
        } else {
          if( gDebug > 0 && event.eventData.id == gCheckEventId) print("$gCheckEventId is not a notification . event from file = ${event.readFromFile}");

        }
      } else {
        // first reaction to this event, create the entry in global map
        List<List<String>> newReactorList = [];
        List<String> temp = [reactorPubkey, comment];
        newReactorList.add(temp);
        gReactions[reactedToId] = newReactorList;
      }
      // set isHidden for reactedTo if it exists in map


      if( comment == "!" &&  event.eventData.pubkey == userPublicKey) {
        tempChildEventsMap[reactedToId]?.event.eventData.isHidden = true;
      }
      return reactedToId;
    } else {
      // case where its not a kind 7 event, or we can't find the reactedTo event due to absense of e tag.
    }

    return "";
  }

  // will go over the list of events, and update the global gReactions appropriately
  static void processReactions(Set<Event> events, Map<String, Tree> tempChildEventsMap) {
    //print("in processReactions");    
    for (Event event in events) {
      processReaction(event, tempChildEventsMap);
    }
    return;
  }

} //================================================================================================================================ end Store

int ascendingTimeTree(Tree a, Tree b) {
  if(a.event.eventData.createdAt < b.event.eventData.createdAt) {
    return -1;
  } else {
    if( a.event.eventData.createdAt == b.event.eventData.createdAt) {
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

/*
 * @function getTree Creates a Tree out of these received List of events. 
 *             Will remove duplicate events( which should not ideally exists because we have a set), 
 *             populate global names, process reactions, remove bots, translate, and then create main tree
 */
Store getTree(Set<Event> events) {
    if( events.isEmpty) {
      if(gDebug > 0) log.info("Warning: In printEventsAsTree: events length = 0");

      List<DirectMessageRoom> temp =[];
      return Store([], {}, [], [], [], temp);
    }

    // remove bots from 42/142/4 messages
    events.removeWhere((event) =>  [42, 142, 4].contains(event.eventData.kind) && gBots.contains( event.eventData.pubkey) );
    events.removeWhere((event) => event.eventData.kind == 42 && event.eventData.content.compareTo("nostrember is finished") == 0);

    // remove all events other than kind 0 (meta data), 1(posts replies likes), 3 (contact list), 7(reactions), 40 and 42 (chat rooms)
    events.removeWhere( (event) => !Store.typesInEventMap.contains(event.eventData.kind));  

    // process kind 0 events about metadata 
    int totalKind0Processed = 0, notProcessed = 0;
    events.forEach( (event) =>  processKind0Event(event)? totalKind0Processed++: notProcessed++);
    if( gDebug > 0) print("In getTree: totalKind0Processed = $totalKind0Processed  notProcessed = $notProcessed gKindONames.length = ${gKindONames.length}"); 


    if( gDebug > 0) log.info("kind 0 finished.");

    // process kind 3 events which is contact list. Update global info about the user (with meta data) 
    int totalKind3Processed = 0, notProcessed3 = 0;
    events.forEach( (event) =>  processKind3Event(event)? totalKind3Processed++: notProcessed3++);
    if( gDebug > 0) print("In getTree: totalKind3Processed = $totalKind3Processed  notProcessed = $notProcessed3 gKindONames.length = ${gKindONames.length}"); 

    if( gDebug > 0) log.info("kind 3 finished.");

    // remove bot events
    //events.removeWhere( (event) => gBots.contains(event.eventData.pubkey));

    // remove duplicate events
    Set ids = {};
    events.retainWhere((event) => ids.add(event.eventData.id));


    if( gDebug > 0) print("In getTree: after removing unwanted kind, number of events remaining: ${events.length}");

    if( gDebug > 0) log.info("Calling fromEvents for ${events.length} events.");
    // create tree from events
    Store node = Store.fromEvents(events);

    // translate and expand mentions for all
    events.where((element) => element.eventData.kind != 142).forEach( (event) =>   event.eventData.translateAndExpandMentions(node.directRooms, node.allChildEventsMap));;
    events.where((element) => element.eventData.kind == 142).forEach( (event) =>   event.eventData.translateAndExpand14x(node.directRooms, node.encryptedChannels, node.allChildEventsMap));;
    if( gDebug > 0) log.info("expand mentions finished.");

    if(gDebug > 0) print("total number of posts/replies in main tree = ${node.count()}");
    return node;
}

//   returns the id of event since only one p is expected in an event ( for future: sort all participants by id; then create a large string with them together, thats the unique id for now)
String getDirectRoomId(EventData eventData) {

  List<String> participantIds = [];
  eventData.tags.forEach((tag) { 
    if( tag.length < 2) 
      return;

      if( tag[0] == 'p') {
        participantIds.add(tag[1]);
      }
  });

  participantIds.sort();
  String uniqueId = "";
  participantIds.forEach((element) {uniqueId += element;}); // TODO ensure its only one thats added s

  // send the other persons pubkey as identifier 
  if( eventData.pubkey == userPublicKey) {
    return uniqueId;
  } else { 
    return eventData.pubkey;
  }
}
