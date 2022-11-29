import 'dart:io';
import 'dart:convert';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:nostr_console/settings.dart';
import 'package:nostr_console/utils.dart';

typedef fTreeSelector = bool Function(Tree a);
typedef fRoomSelector = bool Function(ScrollableMessages room);

Store? gStore = null;

// only show in which user is involved
bool selectorTrees_selfPosts(Tree t) {

  if( userPublicKey == t.event.eventData.pubkey) {
    return true;
  }

  return false;
}

/*
// returns true of the user has received a like or response to this post
bool userHasNotification(String pubkey, Event e) {
  if( e.eventData.pubkey == pubkey && gReactions.containsKey(e.eventData.id) ) {
    List<List<String>>? temp = gReactions[e.eventData.id];
    if( temp != null) {
      if( temp.length > 0) {
        return true;
      }
    }
  }
  return false;
}

// only show in which user is involved
bool selectorTrees_userNotifications(Tree t) {

  if( userHasNotification(userPublicKey, t.event)) {
    return true;
  }

  for( Tree child in t.children) {
    if( selectorTrees_userNotifications(child)) {
      return true;
    }
  }

  return false;
}
*/

bool userInvolved(String pubkey, Event e) {
  if( e.eventData.pubkey == pubkey) {
    return true;
  }

  if( gReactions.containsKey(e.eventData.id)) {
    List<List<String>>? reactors = gReactions[e.eventData.id]??null;
    if( reactors != null) {
      for( var reactor in reactors) {
        String reactorPubkey = reactor[0];
        if( reactorPubkey == pubkey) {
          return true;
        }
      }
    }
  }
  return false;
}

bool selectorTrees_all(Tree t) {
  return true;
}

// only show in which user is involved
bool selectorTrees_userRepliesLikes(Tree t) {
  if( userInvolved(userPublicKey, t.event)) {
    return true;
  }

  for( Tree child in t.children) {
    if( selectorTrees_userRepliesLikes(child)) {
      return true;
    }
  }
  return false;
}

bool followsInvolved(Event e, Event? contactEvent) {

  if( contactEvent == null) {
    return false;
  }

  // if its an event by any of the contact
  if(contactEvent.eventData.contactList.any((contact) => e.eventData.pubkey == contact.id )) {
    return true;
  }

  // check if any of the contact liked it
  if( gReactions.containsKey(e.eventData.id)) {
    List<List<String>>? reactors = gReactions[e.eventData.id]??null;
    if( reactors != null) {
      for( var reactor in reactors) {
        String reactorPubkey = reactor[0];
        if(contactEvent.eventData.contactList.any((contact) => reactorPubkey == contact.id )) {
          return true;
        }
      }
    }
  }
  return false;
}

// only show in which user is involved
bool selectorTrees_followsPosts(Tree t) {
  Event? contactEvent = gKindONames[userPublicKey]?.latestContactEvent;

  if( followsInvolved(t.event, contactEvent)) {
    return true;
  }

  for( Tree child in t.children) {
    if( selectorTrees_followsPosts(child)) {
      return true;
    }
  }
  return false;
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

enum enumRoomType { kind4, kind40, kind140}

class ScrollableMessages {
  String       topHeader;
  List<String> messageIds;
  int          createdAt;
  enumRoomType roomType;

  ScrollableMessages(this.topHeader, this.messageIds, this.createdAt, this.roomType);

  void addMessageToRoom(String messageId, Map<String, Tree> tempChildEventsMap) {
    if( gSpecificDebug > 0 && roomType == enumRoomType.kind140) print("in addMessageToRoom for enc");
    int newEventTime = (tempChildEventsMap[messageId]?.event.eventData.createdAt??0);

    if(gDebug> 0) print("Room has ${messageIds.length} messages already. adding new one to it. ");

    for(int i = 0; i < messageIds.length; i++) {
      int eventTime = (tempChildEventsMap[messageIds[i]]?.event.eventData.createdAt??0);
      if( newEventTime < eventTime) {
        // shift current i and rest one to the right, and put event Time here
        if(gSpecificDebug > 0 && roomType == enumRoomType.kind140) print("In addMessageToRoom: inserted enc message in middle to room with name ${topHeader}");
        messageIds.insert(i, messageId);
        return;
      }
    }
    if(gSpecificDebug > 0 && roomType == enumRoomType.kind140) print("In addMessageToRoom: inserted enc message in end of room with name ${topHeader}");

    // insert at end
    messageIds.add(messageId);
    return;
  }

  void printOnePage(Map<String, Tree> tempChildEventsMap, List<String>? secretMessageIds, List<Channel>? encryptedChannels, [int page = 1] )  {
    if( page < 1) {
      if( gDebug > 0) log.info("In ScrollableMessages::printOnepage  got page = $page");
      page = 1;
    }

    printCenteredHeadline(" $topHeader ");
    print(""); // print new line after channel name info

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
        print(e.eventData.getStrForChannel(0, tempChildEventsMap, secretMessageIds, encryptedChannels));
      }
    }

    if( messageIds.length > gNumChannelMessagesToShow) {
      print("\n");
      printDepth(0);
      stdout.write("${gNotificationColor}Displayed page number ${page} (out of total $numPages pages, where 1st is the latest 'page').\n");
      printDepth(0);
      stdout.write("To see older pages, enter numbers from 1-${numPages}, in format '/N', a slash followed by the required page number.${gColorEndMarker}\n\n");
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
} // end class ScrollableMessages

// Used for all group rooms ( public, encrypted ) 
class Channel extends ScrollableMessages {
  String       channelId; // id of the kind 40 start event
  String       internalChatRoomName; 
  String       about;
  String       picture;
  int          lastUpdated; // used for encryptedChannels
  

  Set<String> participants; // pubkey of all participants - only for encrypted channels
  String      creatorPubkey;      // creator of the channel, if event is known

  enumRoomType roomType;

  Channel(this.channelId, this.internalChatRoomName, this.about, this.picture, List<String> messageIds, this.participants, this.lastUpdated, this.roomType, [this.creatorPubkey=""] ) : 
            super (  internalChatRoomName.isEmpty? channelId: "Channel Name: $internalChatRoomName (id: $channelId)" , 
                     messageIds,
                     lastUpdated,
                     roomType);

  String getChannelId() {
    return channelId;
  }

  String get chatRoomName {
    return internalChatRoomName;
  }

  void set chatRoomName(String newName){
    internalChatRoomName = newName;
    super.topHeader = "Channel Name: $newName (Id: $channelId)";
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

// represents direct chat of kind 4
class DirectMessageRoom extends ScrollableMessages{
  String       otherPubkey; // id of user this DM is happening
  int          createdAt;

  DirectMessageRoom(this.otherPubkey, List<String> messageIds, this.createdAt):
            super ( "${getAuthorName(otherPubkey)} ($otherPubkey)", messageIds, createdAt, enumRoomType.kind4) {
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
    printOnePage(store.allChildEventsMap, null, null, page);
  }
 }

// One node of the Social network tree structure. Is used by Store class to store the social network threads.
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

        if(false && event.eventData.id == "471bb00f66212a594c1e875f708d01fc6aa4ed83d638c928d25e37dee28f8605") 
          print('left shifting for event id: ${event.eventData.id} i = $i child = ${children[i].event.eventData.id} child kind = ${children[i].event.eventData.kind}');

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
  bool treeSelectorRepliesAndLikes(String pubkey) {
    bool hasReaction = false;
    bool childMatches = false;

    if( event.eventData.pubkey == pubkey &&  gReactions.containsKey(event.eventData.id)) {
      List<List<String>>? reactions = gReactions[event.eventData.id];
      if( reactions  != null) {
        if( reactions.length > 0) {
          event.eventData.isNotification = true;
          return true;
        }
      }
    }

    if( event.eventData.pubkey == pubkey && children.length > 0) {
      for( int i = 0; i < children.length; i++ ) {
        children.forEach((child) {  
          // if child is someone else then set notifications and flag, means there are replies to this event 
          childMatches = child.event.eventData.isNotification =  ((child.event.eventData.pubkey != pubkey)? true: false) ; 
        }); 
      }
    }

    for( int i = 0; i < children.length; i++ ) {
      if( children[i].treeSelectorRepliesAndLikes(pubkey)) {
        childMatches = true;
      }
    }

    if( hasReaction || childMatches) {
      return true;
    }
    return false;
  } 

  // returns true if the tree or its children has a post or like by user; and notification flags are set for such events
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
  } // end treeSelectorUserPostAndLike()

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
    if( event.eventData.id == gCheckEventId) printWarning("found the event $gCheckEventId");

    if( event.eventData.content.toLowerCase().contains(word) || event.eventData.id == word ) {
      event.eventData.isNotification = true;
      return true;
    }
    if( childMatches) {
      return true;
    }
    return false;
  } // end treeSelectorHasWords()

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
  } // end treeSelectorClientName()

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
  } // end treeSelectorNotifications()

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
  } // end count()
} // end Tree

/***********************************************************************************************************************************/
/*  
 * The actual tree struture holds only kind 1 events, or only posts. Tree itself can hold any event type( to be fixed, needs renaming etc TODO)
 * This Store class holds events too in its map, and in its chatRooms structure
 */
class Store {
  List<Tree>        topPosts;            // only has kind 1 events

  Map<String, Tree>  allChildEventsMap;   // has events of kind typesInEventMap
  List<String>       eventsWithoutParent;

  List<Channel>   channels = [];
  List<Channel>   encryptedChannels = [];
  List<DirectMessageRoom> directRooms = [];

  List<String>    encryptedGroupSecretIds; // event id's of gSecretMessageKind messages, which contain encrypted room secrets; channel users will look up here for the secret

  static String startMarkerStr = "" ;
  static String endMarkerStr = "";

  static const Set<int>   typesInEventMap = {0, 1, 3, 4, 5, 7, 40, 42, 140, 141, 142, gSecretMessageKind}; // 0 meta, 1 post, 3 follows list, 7 reactions

  Store(this.topPosts, this.allChildEventsMap, this.eventsWithoutParent, this.channels, this.encryptedChannels, this.directRooms, this.encryptedGroupSecretIds) {
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
      case 40:
       {
        String chatRoomId = eId;
        assert(chatRoomId.length == 64);

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
            Channel room = Channel(chatRoomId, roomName, roomAbout, "", emptyMessageList, {}, ce.eventData.createdAt, enumRoomType.kind40);
            rooms.add( room);
          }
        } on Exception catch(e) {
          if( gDebug > 0) print("In From Event. Event type 40. Json Decode error for event id ${ce.eventData.id}. error = $e");
        }
      }
        break;
      case 42:
      {
        String channelId = ce.eventData.getChannelIdForMessage();

        if( channelId.length != 64) {
          break;
        }

        //print( "for event id ${ce.eventData.id} getting channel id of ${channelId} ");
        assert(channelId.length == 64);

        if( channelId != "") { // sometimes people may forget to give e tags or give wrong tags like #e
          Channel? channel = getChannel(rooms, channelId);
          if( channel != null) {
            channel.addMessageToRoom(eId, tempChildEventsMap);
          } else {

            Channel newChannel = Channel(channelId, "", "", "", [eId], {}, 0, enumRoomType.kind40); 
            // message added in above line
            rooms.add( newChannel);
          }
        }
      }
      break;
      default:
        break;  
      } // end switch
  }

  static String? getEncryptedChannelIdFromSecretMessage( List<String> secretMessageIds, Map<String, Tree> tempChildEventsMap, Event eventSecretMessage) {
    String evaluatedContent = eventSecretMessage.eventData.evaluatedContent;

    //print("In getEncryptedChannelIdFromSecretMessage: evaluatedContent length = ${evaluatedContent.length}\nevaluatedContent = ${evaluatedContent} ");
    if( evaluatedContent.startsWith("App Encrypted Channels:")) {
      //print("got App");
      if(evaluatedContent.length == 288) {
        String channelId = evaluatedContent.substring(58, 58 + 64);

        if( channelId.length == 64) {
          return channelId;
        }
      }
    }
    return null;
  }

  /**
   * Will create a entry in encryptedChannels ( if one does not already exist)
   * Returns id of channel if one is created, null otherwise.
   * 
   */
  static String? createEncryptedRoomFromInvite( List<String> secretMessageIds, List<Channel> encryptedChannels, Map<String, Tree> tempChildEventsMap, Event eventSecretMessage) {

    String? event140Id = getEncryptedChannelIdFromSecretMessage(secretMessageIds, tempChildEventsMap, eventSecretMessage);
    Event? event140 = tempChildEventsMap[event140Id]?.event;
    if( event140 != null) {
      String eId = event140.eventData.id;

      Set<String> participants = {};
      event140.eventData.pTags.forEach((element) { participants.add(element);});

      String chatRoomId = eId;
      try {
        dynamic json = jsonDecode(event140.eventData.content);
        Channel? channel = getChannel(encryptedChannels, chatRoomId);
        if( channel != null) {
          // if channel entry already exists, then do nothing, cause we've already processed this channel create event 
        } else {
          // create new encrypted channel
          String roomName = "", roomAbout = "";
          if(  json.containsKey('name') ) {
            roomName = json['name']??"";
          }
          
          if( json.containsKey('about')) {
            roomAbout = json['about'];
          }
          List<String> emptyMessageList = [];
          Channel room = Channel(chatRoomId, roomName, roomAbout, "", emptyMessageList, participants, event140.eventData.createdAt, enumRoomType.kind140, event140.eventData.pubkey);
          encryptedChannels.add( room);
          return chatRoomId;
        }
      } on Exception catch(e) {
        if( gDebug > 0) print("In From Event. Event type 140. Json Decode error for event id ${event140.eventData.id}. error = $e");
      }
    } // end if 140
    else {
      //printWarning("could not find event 140 from event $gSecretMessageKind ${eventSecretMessage.eventData.id}");
    }
    return null;
  }

  static void handleEncryptedChannelEvent( List<String> secretMessageIds, List<Channel> encryptedChannels, Map<String, Tree> tempChildEventsMap, Event ce) {
      String eId = ce.eventData.id;
      int    eKind = ce.eventData.kind;

      if( ce.eventData.createdAt < getSecondsDaysAgo(3)) {
        //return; // dont process old 142/141 messages cause they're different format
      }

      switch(eKind) {
      case 142:
        //if( gSpecificDebug > 0 && eId == gCheckEventId) printWarning("Got ${eId}");
        if( gSpecificDebug > 0) print("got kind 142 message. total number of encrypted channels: ${encryptedChannels.length}. event e tags ${ce.eventData.eTags}");
        String channelId = ce.eventData.getChannelIdForMessage();

        if( channelId.length == 64) { // sometimes people may forget to give e tags or give wrong tags like #e
          Channel? channel = getChannel(encryptedChannels, channelId);
          if( channel != null) {
            channel.addMessageToRoom(eId, tempChildEventsMap);
          } else {
            if( gSpecificDebug > 0) print("could not get channel");
          }
        } else {
          // could not get channel id of message. 
          printWarning("---Could not get encryptd channel for message id ${ce.eventData.id} got channelId : ${channelId} its len ${channelId.length}");
        }
        break;
      case 141:
      
        Set<String> participants = {};
        ce.eventData.pTags.forEach((element) { participants.add(element);});
        
        String chatRoomId = ce.eventData.getChannelIdForMessage();
        if( chatRoomId.length != 64) {
          break;
        }

        try {
          dynamic json = jsonDecode(ce.eventData.content);
          Channel? channel = getChannel(encryptedChannels, chatRoomId);
          if( channel != null) {
            // as channel entry already exists, then update its participants info, and name info
            if( channel.chatRoomName == "" && json.containsKey('name')) {
              channel.chatRoomName = json['name'];
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
                  e.eventData.translateAndDecrypt14x(secretMessageIds, encryptedChannels, tempChildEventsMap);
                }
              }
            }
          } else {
            // encrypted channel is only created on getting invite through kind 104, not here
          }
        } on Exception catch(e) {
          if( gDebug > 0) print("In From Event. Event type 140. Json Decode error for event id ${ce.eventData.id}. error = $e");
        }
        break;

      default:
        break;  
      } // end switch
  }

  // returns 1 if message was to the user; adds the secret message id to tempEncyrp... variable
  static int handleSecretMessageKind(List<String> tempEncryptedSecretMessageIds, Map<String, Tree> tempChildEventsMap, Event ce) {
      int    eKind = ce.eventData.kind;

      if( gSecretMessageKind != eKind || !isValidDirectMessage(ce.eventData)) {
        return 0;
      }

      int i = 0;
      for(i = 0; i < tempEncryptedSecretMessageIds.length; i++) {
        if ( ce.eventData.id == tempEncryptedSecretMessageIds[i]) {
          return 0;
        }
      }

      tempEncryptedSecretMessageIds.add( ce.eventData.id);

      return 1;   
  }

  static int handleDirectMessage( List<DirectMessageRoom> directRooms, Map<String, Tree> tempChildEventsMap, Event ce) {
      String eId = ce.eventData.id;
      int    eKind = ce.eventData.kind;

      int numMessagesDecrypted = 0;

      if( ce.eventData.id == gCheckEventId) {
        printInColor("in handleDirectmessge: $gCheckEventId", redColor);
      }

      if( !isValidDirectMessage(ce.eventData)) {
        if( ce.eventData.id == gCheckEventId) {
          printInColor("in handleDirectmessge: returning", redColor);
        }
        return 0;
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
          //ce.eventData.translateAndExpandMentions(directRooms, tempChildEventsMap);
          if( ce.eventData.evaluatedContent.length > 0) numMessagesDecrypted++;
        } else {
          if( gDebug > 0) print("Could not get chat room id for event ${ce.eventData.id}  sender pubkey = ${ce.eventData.pubkey}.");
        }
      }
      break;
      default:
        break;  
      } // end switch

      return numMessagesDecrypted;
  }
 
  /***********************************************************************************************************************************/
  // @method create top level Tree from events. 
  // first create a map. then process each element in the map by adding it to its parent ( if its a child tree)
  factory Store.fromEvents(Set<Event> events) {
    if( events.isEmpty) {
    List<DirectMessageRoom> temp = [];

      return Store( [], {}, [], [], [], temp, []);
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
    List<String> tempEncryptedSecretMessageIds = [];

    int numEventsNotPosts = 0; // just for debugging info
    int numKind40Events   = 0;
    int numKind42Events   = 0;
    if( gDebug > 0) print("In Tree from Events: after adding all required events of type ${typesInEventMap} to tempChildEventsMap map, its size = ${tempChildEventsMap.length} ");


    //log.info('in middle of fromEvents');
    int totoalDirectMessages = 0;
    tempChildEventsMap.forEach((newEventId, tree) {
      int eKind = tree.event.eventData.kind;

      // these are handled in another iteration ( cause first private messages need to be populated)
      if( eKind == 142 || eKind == 140 || eKind == 141) {
        return;
      }

      if( eKind == 42 || eKind == 40) {
        handleChannelEvents(channels, tempChildEventsMap, tree.event);
        return;
      }

      if( eKind == 4) {
        handleDirectMessage(tempDirectRooms, tempChildEventsMap, tree.event);
        return;
      }

      if( eKind == gSecretMessageKind) {
        // add the event id to given structure if its a valid message
        handleSecretMessageKind(tempEncryptedSecretMessageIds, tempChildEventsMap, tree.event);
        return;
      }

      if( eKind == 7) {
        processReaction(tree.event, tempChildEventsMap);
        return;
      }

      // if reacted to event is not in store, then add it to dummy list so it can be fetched
      try {
        if( tree.event.eventData.eTags.length > 0) {
          if (tree.event.eventData.eTags.last.length > 0) {
            String reactedToId  = tree.event.eventData.eTags.last[0];
            // only if the reaction was made recently in last 3 days
            // TODO while storing need to store these newly fetched events too; otherwise these are fetched everytime
            if( false && !tempChildEventsMap.containsKey(reactedToId) && tree.event.eventData.createdAt > getSecondsDaysAgo(3)) {
              print("liked event not found in store.");
              dummyEventIds.add(reactedToId);
            }
          }
        }
      }  catch(e) {
        print(e);
      }

      if( tree.event.eventData.id == gCheckEventId) {
        print("In fromEvent: got evnet id $gCheckEventId");
      }

      if( tree.event.eventData.kind != 1) {
        return;
      }

      // find its parent and then add this element to that parent Tree
      String parentId = tree.event.eventData.getParent(tempChildEventsMap);

      if( parentId != "") {

        if( tree.event.eventData.id == gCheckEventId) {
          if(gDebug >= 0) print("In Tree FromEvents: e tag not empty. its parent id = $parentId  for id: $gCheckEventId");
        }

        if(tempChildEventsMap.containsKey( parentId)) {
          // if parent is in store
          if( tree.event.eventData.id == gCheckEventId) {
            if(gDebug >= 0) print("In Tree FromEvents: found its parent $parentId : for id: $gCheckEventId");
          }

          if( tempChildEventsMap[parentId]?.event.eventData.kind != 1) {
            // first check there isn't already a dummy in top trees
            bool dummyParentAlreadyExists = false;
            for( int i = 0; i < topLevelTrees.length; i++) {
              if( topLevelTrees[i].event.eventData.id == parentId) {
                dummyParentAlreadyExists = true;
                topLevelTrees[i].children.add(tree); 
                break;
              }
            }

            if(!dummyParentAlreadyExists) {
              Event dummy = Event("","",  EventData(parentId,gDummyAccountPubkey, tree.event.eventData.createdAt, 1, "<Parent is not of Kind 1>", [], [], [], [[]], {}), [""], "[json]");

              Tree dummyTopNode = Tree.withoutStore(dummy, []);
              dummyTopNode.children.add(tree);   
              topLevelTrees.add(dummyTopNode);
            } // else is handled in above for loop itself
            
            tempWithoutParent.add(tree.event.eventData.id); 
            // dont add this dummy in dummyEventIds list ( cause that's used to fetch events not in store)
          } else {
            tempChildEventsMap[parentId]?.children.add(tree);
          }
        } else {
          // in case where the parent of the new event is not in the pool of all events, 
          // then we create a dummy event and put it at top ( or make this a top event?) TODO handle so that this can be replied to, and is fetched

          if( parentId.length == 64) {
            // add the dummy evnets to top level trees, so that their real children get printed too with them so no post is missed by reader

            // first check there isn't already a dummy in top trees
            bool dummyParentAlreadyExists = false;
            for( int i = 0; i < topLevelTrees.length; i++) {
              if( topLevelTrees[i].event.eventData.id == parentId) {
                dummyParentAlreadyExists = true;
                topLevelTrees[i].children.add(tree); 
                break;
              }
            }

            if(!dummyParentAlreadyExists) {
              // kind 1 is needed to enable search etc . the dummy pubkey distinguishes it as a dummy node
              Event dummy = Event("","",  EventData(parentId,gDummyAccountPubkey, tree.event.eventData.createdAt, 1, "Event not loaded", [], [], [], [[]], {}), [""], "[json]");

              Tree dummyTopNode = Tree.withoutStore(dummy, []);
              dummyTopNode.children.add(tree);
              tempWithoutParent.add(tree.event.eventData.id); 
              dummyEventIds.add(parentId);
              topLevelTrees.add(dummyTopNode);
            }
            //printWarning("Added unknown event as top : ${parentId}");
          }
          else {
            if( gDebug > 0) {
              print("--------\ngot invalid parentId in fromEvents: $parentId");
              print("original json of event:\n${tree.event.originalJson}");
            }
          }
            
        }
      } else {
        // is not a parent, has no parent tag. then make it its own top tree, which will be done later in this function
      }
    }); // going over tempChildEventsMap and adding children to their parent's .children list

    // for pubkeys that don't have any kind 0 events ( but have other evnets), add then to global kind0 store so they can still be accessed
    tempChildEventsMap.forEach((key, value) {
        if( !gKindONames.containsKey(value.event.eventData.pubkey)) {
          gKindONames[value.event.eventData.pubkey] = UserNameInfo(null, null, null, null, null, null );
        }
    });

    // tempEncrytedSecretMessageIds has been created above 
    // now create encrypted rooms
    Set<String> usersEncryptedGroups = {};
    tempEncryptedSecretMessageIds.forEach((secretEventId) {
      Event? secretEvent = tempChildEventsMap[secretEventId]?.event;
      
      if( secretEvent != null) {
        secretEvent.eventData.TranslateAndDecryptSecretMessage(tempChildEventsMap);
        String? newEncryptedChannelId = createEncryptedRoomFromInvite(tempEncryptedSecretMessageIds, encryptedChannels, tempChildEventsMap, secretEvent);
        if( newEncryptedChannelId != null) {
          usersEncryptedGroups.add(newEncryptedChannelId);
        }
      }
    });

    tempChildEventsMap.forEach((newEventId, tree) {
      int eKind = tree.event.eventData.kind;
      if( eKind == 142  || eKind == 141) {
        handleEncryptedChannelEvent(tempEncryptedSecretMessageIds, encryptedChannels, tempChildEventsMap, tree.event);
      }
    });

    // add parent trees as top level child trees of this tree
    for( var tree in tempChildEventsMap.values) {
      if( tree.event.eventData.kind == 1 &&  tree.event.eventData.getParent(tempChildEventsMap) == "") {  // only posts which are parents
        topLevelTrees.add(tree);
      }
    }

    if(gDebug != 0) print("In Tree FromEvents: number of events without parent in fromEvents = ${tempWithoutParent.length}");

    // get dummy events
    sendEventsRequest(gListRelayUrls1, dummyEventIds);

    // get encrypted channel events,  get 141/142 by their mention of channels to which user has been invited through kind 104. get 140 by its event id.
    for(String newEncryptedGroup in usersEncryptedGroups) {
      getMentionEvents(gListRelayUrls2, newEncryptedGroup, gLimitFollowPosts, getSecondsDaysAgo(gDefaultNumLastDays), "#e"); // from relay group 2
    }
    
    sendEventsRequest(gListRelayUrls1, usersEncryptedGroups);
    

    // create a dummy top level tree and then create the main Tree object
    return Store( topLevelTrees, tempChildEventsMap, tempWithoutParent, channels, encryptedChannels, tempDirectRooms, tempEncryptedSecretMessageIds);
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

      // expand mentions ( and translate if flag is set) and then add event to main event map; 142 events are expanded later
      if( newEvent.eventData.kind != 142) 
        newEvent.eventData.translateAndExpandMentions( allChildEventsMap); // this also handles dm decryption for kind 4 messages, for kind 1 will do translation/expansion; 

      // add them to the main store of the Tree object, but after checking that its not one of the dummy/missing events. 
      // In that case, replace the older dummy event, and only then add it to store-map
      // Dummy events are only added as top posts, so search there for them.
      for(int i = 0; i < topPosts.length; i++) {
        Tree tree = topPosts[i];
        if( tree.event.eventData.id == newEvent.eventData.id) {
          // its a replacement. 
          if( gDebug >= 0 && newEvent.eventData.id == gCheckEventId) log.info("In processIncoming: Replaced old dummy event of id: ${newEvent.eventData.id}");
          tree.event = newEvent;
          allChildEventsMap[tree.event.eventData.id] = tree;
          return;
        }
      }

      allChildEventsMap[newEvent.eventData.id] = Tree(newEvent, [], this);

      // add to new-notification list only if this is a recent event ( because relays may send old events, and we dont want to highlight stale messages)
      newEventIdsSet.add(newEvent.eventData.id);
     
    });
    
    // now go over the newly inserted event, and add it to the tree for kind 1 events, add 42 events to channels. rest ( such as kind 0, kind 3, kind 7) are ignored.
    newEventIdsSet.forEach((newId) {
      Tree? newTree = allChildEventsMap[newId];
      if( newTree != null) {  // this should return true because we just inserted this event in the allEvents in block above

        switch(newTree.event.eventData.kind) {
          case 1:
            // only kind 1 events are added to the overall tree structure
            String parentId = newTree.event.eventData.getParent(allChildEventsMap);
            if( parentId == "471bb00f66212a594c1e875f708d01fc6aa4ed83d638c928d25e37dee28f8605") print("Found child of 471bb00f66212a594c1e875f708d01fc6aa4ed83d638c928d25e37dee28f8605 id = ${newTree.event.eventData.id}");
            if( parentId == "") {
                // if its a new parent event, then add it to the main top parents 
                topPosts.add(newTree);
            } else {
                // if it has a parent , then add the newTree as the parent's child
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
          case 42:
            handleChannelEvents(channels, allChildEventsMap, newTree.event);
            break;

          case 141:
          case 142:
            handleEncryptedChannelEvent(encryptedGroupSecretIds, encryptedChannels, allChildEventsMap, newTree.event);
            break;

          case gSecretMessageKind:
            if( isValidDirectMessage(newTree.event.eventData)) {
              String ? temp = newTree.event.eventData.TranslateAndDecryptSecretMessage( allChildEventsMap); 
              if( temp != null) {
                encryptedGroupSecretIds.add(newTree.event.eventData.id);
                createEncryptedRoomFromInvite(encryptedGroupSecretIds, encryptedChannels, allChildEventsMap, newTree.event);
              }
            } else {
              //print("1. kind $gSecretMessageKind with id ${newTree.event.eventData.id} is not a valid direct message to user. ");
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

    String strToWrite = "";
    int countNotificationEvents = 0;
    for( var newEventId in newEventIdsSet) {
      int k = (allChildEventsMap[newEventId]?.event.eventData.kind??-1);
      if( k == 7 || k == 1 ) {
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
      return;
    }
    // TODO call count() less
    strToWrite += "Number of new replies/posts = ${newEventIdsSet.length}\n";
    stdout.write("${getNumDashes(strToWrite.length -1 )}\n$strToWrite");
    //stdout.write("Total posts  : ${count()}\n");
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
            String reactedTo  = event.eventData.eTags[lastEIndex][0];
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
      print("\n");
    });
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

    if( numPrinted > 0) {
      print("\nTotal posts printed: $numPrinted for last $gNumLastDays days.\n");
    }

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
   * @printAllChennelsInfo Print one line information about all channels, which are type 40 events ( class ChatRoom) and for 14x channels both; channelsToPrint is different for both
   */
  int printChannelsOverview(List<Channel> channelstoPrint, int numRoomsOverview, fRoomSelector selector, var tempChildEventsMap , List<String>? secretMessageIds) {

    channelstoPrint.sort(scrollableCompareTo);
    int numChannelsActuallyPrinted = 0;

    if( channelstoPrint.length < numRoomsOverview) {
      numRoomsOverview = channelstoPrint.length;
    }

    print("\n\n");
    printUnderlined("  id      Channel Name                Num of Messages            Latest Message                       ");
    for(int j = 0; j < numRoomsOverview; j++) {

      if( channelstoPrint[j].participants.length > 0 &&  !channelstoPrint[j].participants.contains(userPublicKey)) {
        continue;
      }

      if( !selector(channelstoPrint[j]) ) {
        continue;
      }

      String name = "";
      String id = channelstoPrint[j].channelId.substring(0, 6);
      if( channelstoPrint[j].chatRoomName != "") {
        name = "${channelstoPrint[j].chatRoomName}";
      }

      int numMessages = channelstoPrint[j].getNumValidMessages();
      stdout.write("$id    ${name} ${getNumSpaces(32-name.length)}  $numMessages${getNumSpaces(20- numMessages.toString().length)}"); 
      numChannelsActuallyPrinted++;
      List<String> messageIds = channelstoPrint[j].messageIds;
      for( int i = messageIds.length - 1; i >= 0; i--) {
        if( allChildEventsMap.containsKey(messageIds[i])) {
          Event? e = allChildEventsMap[messageIds[i]]?.event;
          if( e!= null) {
            if( !(e.eventData.kind == 142 && e.eventData.content == e.eventData.evaluatedContent)) {
              stdout.write("${e.eventData.getAsLine(tempChildEventsMap, secretMessageIds, channelstoPrint)}");
              break; // print only one event, the latest one
            }
          }
        }
      }
      print("");
    }

    print("");
    print("Showing $numChannelsActuallyPrinted channels\n");

    return numChannelsActuallyPrinted;
  }

  void printChannel(Channel room, Map<String, Tree>? tempChildEventsMap, List<String>? secretMessageIds, List<Channel>? encryptedChannels, [int page = 1])  {
    if( page < 1) {
      if( gDebug > 0) log.info("In printChannel got page = $page");
      page = 1;
    }

    room.printOnePage(allChildEventsMap, secretMessageIds, encryptedChannels, page);
  }

  // prints some info about the encrypted channel
  void printEncryptedChannelInfo(Channel room) {
    // write owner
    String creator = room.creatorPubkey;
    print("\n\n");
    stdout.write("Encrypted channel admin: ");
    printInColor(getAuthorName(creator), gCommentColor);

    // write participants 
    stdout.write("\nChannel participants   : ");
    
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

  // works for both 4x and 14x channels
  // shows the given channelId, where channelId is prefix-id or channel name as mentioned in room.name. returns full id of channel.
  // looks for channelId in id first, then in names. 
  String showChannel(List<Channel> listChannels, String channelId, Map<String, Tree>? tempChildEventsMap, List<String>? secretMessageIds, List<Channel>? encryptedChannels, [int page = 1]) {
    if( channelId.length > 64 ) {
      return "";
    }

    // first check channelsId's, in case user has sent a channelId itself
    Set<String> fullChannelId = {};
    for(int i = 0; i < listChannels.length; i++) {
      if( listChannels[i].channelId.length != 64) {
        //printWarning("For index i = $i channel id len is ${listChannels[i].channelId.length} and listChannels[i].channelId.length = ${listChannels[i].channelId.length}");
        continue;
      }
      
      if( listChannels[i].channelId.substring(0, channelId.length) == channelId ) {
        fullChannelId.add(listChannels[i].channelId);
      }
    }

    if(fullChannelId.length < 1) {
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
        printChannel(room, tempChildEventsMap, secretMessageIds, encryptedChannels, page);
      }
      return fullChannelId.first;
    } else {
      if( fullChannelId.length == 0) {
        printWarning("Could not find the channel.");
      }
      else {
        printWarning("Found more than 1 channel: $fullChannelId");
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
  int printDirectRoomInfo(fRoomSelector roomSelector, var tempChildEventsMap) { 
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
    stdout.write("\n\n");
    
    printUnderlined("Pubkey   From                                Num of Messages          Latest Message           ");
    for( int j = 0; j < directRooms.length; j++) {
      if( !roomSelector(directRooms[j]))
        continue;
      DirectMessageRoom room = directRooms[j];
      String id = room.otherPubkey.substring(0, 6);
      String name = getAuthorName(room.otherPubkey, 4);

      int numMessages = room.messageIds.length;
      stdout.write("$id   ${name} ${getNumSpaces(32-name.length)}          $numMessages${getNumSpaces(12- numMessages.toString().length)}"); 

      // print latest event in one line
      List<String> messageIds = room.messageIds;
      for( int i = messageIds.length - 1; i >= 0; i++) {
        if( allChildEventsMap.containsKey(messageIds[i])) {
          numRoomsActuallyPrinted++;
          Event? e = allChildEventsMap[messageIds[i]]?.event;
          if( e!= null) {
            String line = e.eventData.getAsLine(tempChildEventsMap, null, null);
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

      String otherName = getAuthorName( directRooms[j].otherPubkey);
      if( otherName.length >= directRoomId.length) {
        if( otherName.substring(0, directRoomId.length).toLowerCase() == directRoomId.toLowerCase()){
          lookedUpName.add(roomId);
        }
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
       printWarning("Got more than one public id for the name given, which are: ");
       for(String pubkey in lookedUpName) {
        print("${getAuthorName(pubkey)} - ${pubkey}, ");
       }
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

        // only write if its not too old ( except in case of user logged in)
        if( gDontWriteOldEvents) {
          if(  tree.event.eventData.createdAt <  getSecondsDaysAgo(gDontSaveBeforeDays) ) {
            if( tree.event.eventData.pubkey != userPublicKey ) {
              if( !(tree.event.eventData.kind == 4 && isValidDirectMessage(tree.event.eventData)))
                if( !tree.event.eventData.pTags.contains(userPublicKey))
                  if( ![0, 3, 40, 41, 140, 141].contains(tree.event.eventData.kind))
                    continue;
            
            }
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
      if( gWhetherToSendClientTag)
        return '["client","$clientName"]';
      return "[]";
    }

    String strTags = "";

    // find the latest event with the given id; needs to be done because we allow user to refer to events with as few as 3 or so first letters
    // and only the event that's latest is considered as the intended recipient ( this is not perfect, but easy UI)
    int latestEventTime = 0;
    String latestEventId = "";
    for(  String k in allChildEventsMap.keys) {
      if( k.length >= replyToId.length && k.substring(0, replyToId.length) == replyToId) {
        // ignore future events TODO

        if(  [1, 40, 140].contains(allChildEventsMap[k]?.event.eventData.kind)   
            && ( allChildEventsMap[k]?.event.eventData.createdAt ?? 0) > latestEventTime ) {
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

    // found the id of event we are replying to; now gets its top event to set as root, if there is one
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
      strTags +=  '["e","$latestEventId","$relay","reply"]';
    }

    if( gWhetherToSendClientTag)
      strTags += ',["client","$clientName"]' ;
    
    return strTags;
  }

  /*
   * @getTagsFromEvent Searches for all events, and creates a json of e-tag type which can be sent with event
   *                   Also adds 'client' tag with application name.
   * @parameter replyToId First few letters of an event id for which reply is being made
   */
  String getTagStrForChannel(Channel channel, String clientName, [bool addAllP = false]) {
    String channelId = channel.channelId;
    clientName = (clientName == "")? "nostr_console": clientName; // in case its empty 
    String strTags = "";
    strTags +=  '["e","$channelId"],';
    strTags += '["client","$clientName"]' ;
    return strTags;
  }

  /*
   * @getTagsFromEvent Searches for all events, and creates a json of e-tag type which can be sent with event
   *                   Also adds 'client' tag with application name.
   * @parameter replyToId First few letters of an event id for which reply is being made
   */
  String getTagStrForChannelReply(Channel channel, String replyToId, String clientName, [bool addAllP = false]) {
    String channelId = channel.channelId;

    clientName = (clientName == "")? "nostr_console": clientName; // in case its empty 
    if( replyToId.isEmpty) {
      return '["client","$clientName"]';
    }

    String strTags = "";

    // find the latest event with the given id; needs to be done because we allow user to refer to events with as few as 3 or so first letters
    // and only the event that's latest is considered as the intended recipient ( this is not perfect, but easy UI)
    int latestEventTime = 0;
    String latestEventId = "";
    for( int i = channel.messageIds.length - 1; i >= 0; i--) {
      String eventId = channel.messageIds[i];

      if( replyToId == eventId.substring(0, replyToId.length)) {
        if( ( allChildEventsMap[eventId]?.event.eventData.createdAt ?? 0) > latestEventTime ) {
          latestEventTime = allChildEventsMap[eventId]?.event.eventData.createdAt ?? 0;
          latestEventId = eventId;
          break;
        }
      }
    }

    // in case we are given valid length id, but we can't find the event in our internal db, then we just send the reply to given id
    if( latestEventId.isEmpty && replyToId.length == 64) {
      latestEventId = replyToId;  
    }

    if( latestEventId.isEmpty && replyToId.length != 64 && replyToId.length != 0) {
      printWarning('Could not find the given id: $replyToId. Sending a regular message.');
    }

    strTags +=  '["e","$channelId"],';
    // found the id of event we are replying to; now gets its top event to set as root, if there is one
    if( latestEventId.isNotEmpty) {
      String? pTagPubkey = allChildEventsMap[latestEventId]?.event.eventData.pubkey;
      String relay = getRelayOfUser(userPublicKey, pTagPubkey??"");
      relay = (relay == "")? defaultServerUrl: relay;
      strTags +=  '["e","$latestEventId"],';

      if( pTagPubkey != null) {
        strTags += '["p","$pTagPubkey"],';
      }
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


    if( event.eventData.kind == 7 
      && event.eventData.eTags.isNotEmpty) {

      if  ( event.eventData.content == "" 
        || event.eventData.content == "❤️"
        || event.eventData.content == "🙌"
        
          ) { // cause damus sends blank reactions, and some send heart emojis
        event.eventData.content = "+";
      }

      if(gDebug > 1) ("Got event of type 7"); // this can be + or !, which means 'hide' event for me
      String reactorPubkey  = event.eventData.pubkey;
      String reactorId      = event.eventData.id;
      String comment    = event.eventData.content;
      int    lastEIndex = event.eventData.eTags.length - 1;
      String reactedToId  = event.eventData.eTags[lastEIndex][0];

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
    for (Event event in events) {
      processReaction(event, tempChildEventsMap);
    }
    return;
  }

  void printEventInfo() {
    Map<int, int> eventCounterMap = {} ;

    List<int> kindCounted = [0, 1, 3, 4, 5, 6, 7, 40, 41, 42, 140, 141, 142];
    for( var k in kindCounted ) {
      eventCounterMap[k] = 0;
    }

    for(var t in allChildEventsMap.values) {
      EventData e = t.event.eventData;
      eventCounterMap[e.kind] = eventCounterMap[e.kind]??0 + 1;
      if( eventCounterMap.containsKey(e.kind)) {
        eventCounterMap[e.kind] = eventCounterMap[e.kind]! + 1;
      } else {
        eventCounterMap[e.kind] = 0;
      }
    }

    printUnderlined("kind       count");
    for( var k in kindCounted) {
      print("${k.toString().padRight(5)}      ${eventCounterMap[k]}");
    }
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
    //log.info("Entered getTree for ${events.length} events");

    if( events.isEmpty) {
      List<DirectMessageRoom> temp =[];
      return Store([], {}, [], [], [], temp, []);
    }

    // remove posts older than 20 days or so
    //events.removeWhere((event) => [1, 7, 42].contains(event.eventData.kind) && event.eventData.createdAt < getSecondsDaysAgo(gDeletePostsOlderThanDays));

    // remove bots from 42/142/4 messages
    events.removeWhere((event) =>  [42, 142, 4].contains(event.eventData.kind) && gBots.contains( event.eventData.pubkey) );
    events.removeWhere((event) => event.eventData.kind == 42 && event.eventData.content.compareTo("nostrember is finished") == 0);

    // remove all events other than kind 0 (meta data), 1(posts replies likes), 3 (contact list), 7(reactions), 40 and 42 (chat rooms)
    events.removeWhere( (event) => !Store.typesInEventMap.contains(event.eventData.kind));  

    // remove duplicate events
    Set ids = {};
    events.retainWhere((event) => ids.add(event.eventData.id));

    // process kind 0 events about metadata 
    events.forEach( (event) =>  processKind0Event(event));

    // process kind 3 events which is contact list. Update global info about the user (with meta data) 
    events.forEach( (event) =>  processKind3Event(event));

    // create tree from events
    Store node = Store.fromEvents(events);

    // translate and expand mentions 
    events.where((element) => [1, 42, gSecretMessageKind].contains(element.eventData.kind)).forEach( (event) =>   event.eventData.translateAndExpandMentions( node.allChildEventsMap));;
    events.where((element) => element.eventData.kind == 142).forEach( (event) => event.eventData.translateAndDecrypt14x(node.encryptedGroupSecretIds, node.encryptedChannels, node.allChildEventsMap));;

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
