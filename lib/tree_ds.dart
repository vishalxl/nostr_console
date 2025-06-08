import 'dart:io';
import 'dart:convert';
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/relays.dart';
import 'package:nostr_console/utils.dart';
import 'package:nostr_console/settings.dart';
import 'package:nostr_console/user.dart';
// for Point 
 

typedef fTreeSelector = bool Function(Tree a);
typedef fTreeSelector_int = int Function(Tree a);

typedef fRoomSelector = bool Function(ScrollableMessages room);

typedef fvisitorMarkNotifications = void Function(Event e);

Store? gStore;

// only show in which user is involved
bool selectorTrees_selfPosts(Tree t) {

  if( userPublicKey == t.event.eventData.pubkey) {
    return true;
  }

  return false;
}

// returns true of user has made this comment, or liked it 
bool userInvolved(String pubkey, Event e) {

  if( e.eventData.pubkey == pubkey) {
    e.eventData.isNotification = true;
    return true; // if its users comment no need to check further
  }

  if( gReactions.containsKey(e.eventData.id)) {
    List<List<String>>? reactors = gReactions[e.eventData.id];
    if( reactors != null) {
      for( var reactor in reactors) {
        String reactorPubkey = reactor[0];
        // if user has reacted to this event, then return true
        if( reactorPubkey == pubkey) {
          e.eventData.newLikes = {pubkey};
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
  bool usersEvent = false;
  bool childNotifications = false;

  if( userInvolved(userPublicKey, t.event)) {
    usersEvent = true;
  }
  
  for( Tree child in t.children) {
    if( selectorTrees_userRepliesLikes(child)) {
      childNotifications = true;
    }
  }

  if( usersEvent || childNotifications) {
    return true;
  }

  return false;
}

bool followsInvolved(Event e, Event? contactEvent) {

  if( contactEvent == null) {
    return false;
  }

  // if its an event by any of the contact
  if(contactEvent.eventData.contactList.any((contact) => e.eventData.pubkey == contact.contactPubkey )) {
    return true;
  }

  // check if any of the contact liked it
  if( gReactions.containsKey(e.eventData.id)) {
    List<List<String>>? reactors = gReactions[e.eventData.id];
    if( reactors != null) {
      for( var reactor in reactors) {
        String reactorPubkey = reactor[0];
        if(contactEvent.eventData.contactList.any((contact) => reactorPubkey == contact.contactPubkey )) {
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

bool selectorShowOnlyPublicChannel(ScrollableMessages room) {
  if( room.roomType == enumRoomType.kind40) {
    return true;
  }
  else { 
    return false; 
  }
}

bool selectorShowOnlyTagChannel(ScrollableMessages room) {
  if( room.roomType == enumRoomType.RoomTTag) {
    return true;
  }
  else { 
    return false; 
  }
}


bool showAllRooms (ScrollableMessages room) => selectorShowAllRooms(room);

int getLatestMessageTime(ScrollableMessages channel) {

  List<String> messageIds = channel.messageIds;
  if(gStore == null) {
    return 0;
  }

  if(messageIds.isEmpty) {
    int createdAt = channel.createdAt;
    return createdAt;
  }

  int latest = 0;
  for(int i = 0; i < messageIds.length; i++) {
    if( gStore != null) {
      Tree? tree = (gStore?.allChildEventsMap[messageIds[i]]  );
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
    if( channels[i].channelId.toLowerCase() == channelId.toLowerCase()) {
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

  if( gStore == null) {
    return 0;
  }

  int otherLatest = getLatestMessageTime(b);
  int thisLatest =  getLatestMessageTime(a);

  if( thisLatest < otherLatest) {
    return -1;
  } else {
    if( thisLatest == otherLatest) {
      return 0;
    } else {
      return 1;
    }
  }
}

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
        if(gSpecificDebug > 0 && roomType == enumRoomType.kind140) print("In addMessageToRoom: inserted enc message in middle to room with name $topHeader");
        messageIds.insert(i, messageId);
        return;
      }
    }
    if(gSpecificDebug > 0 && roomType == enumRoomType.kind140) print("In addMessageToRoom: inserted enc message in end of room with name $topHeader");

    // insert at end
    messageIds.add(messageId);
    return;
  }

  void printOnePage(Map<String, Tree> tempChildEventsMap, Set<String>? secretMessageIds, List<Channel>? encryptedChannels, [int page = 1] )  {
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
      stdout.write("${gNotificationColor}Displayed page number $page (out of total $numPages pages, where 1st is the latest 'page').\n");
      printDepth(0);
      stdout.write("To see older pages, enter numbers from 1-$numPages, in format '/N', a slash followed by the required page number.$gColorEndMarker\n\n");
    }
  }

  bool selectorNotifications() {
    if( gStore == null) {
      return false;
    }

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

 // will visit every event in the scrollable . used to reset all notifications etc.
  void visitAllMessages(Store node, fScrollableEventVisitor) {
    for(int i = 0; i < messageIds.length; i++) {
      EventData? ed = node.allChildEventsMap[messageIds[i]]?.event.eventData;
      if( ed != null) {
        ed.isNotification = false;
      }
    }    
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

  @override
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

  set chatRoomName(String newName){
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
  @override
  int          createdAt;

  DirectMessageRoom(this.otherPubkey, List<String> messageIds, this.createdAt):
            super ( "${(otherPubkey)} ($otherPubkey)", messageIds, createdAt, enumRoomType.kind4);

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
  
  /// ********************************************************************************************************************************
  /* The main print tree function. Calls the reeSelector() for every node and prints it( and its children), only if it returns true. 
   * returns Point , where first int is total Threads ( or top trees) printed, and second is notifications printed
   * returns list< total top threads printed, total events printed, total notifications printed> 
   */
  List<int> printTree(int depth, DateTime newerThan, bool topPost, [int countPrinted = 0, int maxToPrint = gMaxEventsInThreadPrinted, bool userRelevant = false]) { 
    List<int> ret = [0,0,0];

    if(event.eventData.isNotification || event.eventData.newLikes.isNotEmpty) {
      ret[2] = 1;
    }

    countPrinted++;

    // toggle flag which will save the event and program end
    if( userRelevant == true) {
      event.userRelevant = true;
    }

    event.printEvent(depth, topPost);
    ret[1] = 1; 

    if( countPrinted > maxToPrint) {
      //print("$countPrinted > $maxToPrint");
      print("");
      printDepth(0);
      print(gWarning_TOO_MANY_TREES);
      return ret;
    }

    // sort children by time
    if( children.length > 1) {
      children.sort(sortTreeByItsTime);
    }

    bool leftShifted = false;
    for( int i = 0; i < children.length; i++) {

      if( countPrinted > maxToPrint) {
        break;
      }

      // if the thread becomes too 'deep' then reset its depth, so that its 
      // children will not be displayed too much on the right, but are shifted
      // left by about <leftShiftThreadsBy> places
      if( depth > maxDepthAllowed) {
        depth = maxDepthAllowed - leftShiftThreadsBy;
        printDepth(depth+1);
        stdout.write("    ┌${getNumDashes((leftShiftThreadsBy + 1) * gSpacesPerDepth - 1, "─")}┘\n");        
        leftShifted = true;
      }

      List<int> temp = children[i].printTree(depth+1, newerThan, false, countPrinted, maxToPrint, userRelevant);
      ret[1] += temp[1];
      ret[2] += temp[2];
      countPrinted += temp[1];
    }

    // https://gist.github.com/dsample/79a97f38bf956f37a0f99ace9df367b9
    if( leftShifted) {
      stdout.write("\n");
      printDepth(depth+1);
      print("    ┴"); // same spaces as when its left shifted
    } // end for loop

    return ret;
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

  // returns true if the tree or its children has a reply or like for the user with public key pk; and notification flags are set for such events
  // only new controls whether replies/likes recieved are ignored if the user has already 
  bool treeSelectorotificationsFor(Set<String> pubkeys, [bool onlyNew = false]) {
    bool hasReaction  = false;
    bool childMatches = false;
    bool isMentioned  = false;

    // check if there are any likes to this event if its user's event
    if( pubkeys.contains(event.eventData.pubkey) &&  gReactions.containsKey(event.eventData.id)) {
      List<List<String>>? reactions = gReactions[event.eventData.id];
      if( reactions  != null) {
        if( reactions.isNotEmpty) {
          // set every reaction as a new like so they all get highlighted; these are all later reset after first printing
          Set<String> reactorPubkeys = getReactorPubkeys(event.eventData.id);
          event.eventData.newLikes = reactorPubkeys;
          hasReaction = true;
        }
      }
    }

    // check if any of the users has been tagged in this event
    List<String> pTags = event.eventData.pTags;
    Set<String> pplTagged = pTags.toSet().intersection(pubkeys);

    // 2nd condition: person making the event should not be on this list; they would already be considered in other test
    if( pplTagged.isNotEmpty && !pubkeys.contains(event.eventData.pubkey)) { 
      event.eventData.isNotification = isMentioned = true;
    }

    // check if there are any replies from other people to an event made by someone in list
    if( pubkeys.contains(event.eventData.pubkey) && children.isNotEmpty) {
      for( int i = 0; i < children.length; i++ ) {
        for (var child in children) {  
          // if child is someone else then set notifications and flag, means there are replies to this event 
           if(child.event.eventData.pubkey != event.eventData.pubkey ) {
             // tests reply is not from same user
             childMatches = child.event.eventData.isNotification = true;
           }
        } 
      }
    }

    for( int i = 0; i < children.length; i++ ) {
      if( children[i].treeSelectorotificationsFor(pubkeys)) {
        childMatches = true;
      }
    }

    if( hasReaction || childMatches || isMentioned) {
      return true;
    }
    return false;
  } 

  // returns true if the tree has a reply by any of the pubkeys sent
  // only used by writefile
  bool treeSelectorUserPosted(Set<String> pubkeys, [bool checkChildrenToo = false]) {

    if( pubkeys.contains(event.eventData.pubkey)) {
      return true;
    }

    for( int i = 0; i < children.length; i++ ) {
      if( children[i].treeSelectorUserPosted(pubkeys)) {
        return true;
      }
    }

    return false;
  } 

  // returns true if the tree has a reply by any of the pubkeys sent
  // only used by writefile
  bool treeSelectorUserReplies(Set<String> pubkeys) {

    for( int i = 0; i < children.length; i++ ) {
      if( children[i].treeSelectorUserPosted(pubkeys)) {
        return true;
      }
    }

    return false;
  } 

  // returns true if the tree mentions ( or is a reply to) any of the pubkeys sent
  // only used by writefile
  bool treeSelectorUserMentioned(Set<String> pubkeys) {
    for( int i = 0; i < event.eventData.pTags.length; i++ ) {
      if(  pubkeys.contains( event.eventData.pTags[i][0] )) {
        return true;
      }
    }

    return false;
  } 



  // returns true if the tree (or its children, depending on flag) has a post or like by user; and notification flags are set for such events
  bool treeSelectorUserPostAndLike(Set<String> pubkeys, { bool enableNotifications = true, bool checkChildrenToo = true}) {
    bool hasReacted = false;

    if( gReactions.containsKey(event.eventData.id))  {
      List<List<String>>? reactions = gReactions[event.eventData.id];
      if( reactions  != null) {
        for( int i = 0; i < reactions.length; i++) {
          if( pubkeys.contains(reactions[i][0]) ) {
            if( enableNotifications) {
              event.eventData.newLikes.add(reactions[i][0]);
            }
            hasReacted = true;
          }
        }
      }
    }

    bool childMatches = false;

    if( checkChildrenToo ) {
      for( int i = 0; i < children.length; i++ ) {
        if( children[i].treeSelectorUserPostAndLike(pubkeys, enableNotifications: enableNotifications)) {
          childMatches = true;
        }
      }
    }

    // if event is by user(s)
    if( pubkeys.contains(event.eventData.pubkey)) {
      if( enableNotifications) {
        event.eventData.isNotification = true;
      }
      return true;
    }
    if( hasReacted || childMatches) {
      return true;
    }
    return false;
  } // end treeSelectorUserPostAndLike()

  // returns true if the tree (or its children, depending on flag) has a post or like by user; and notification flags are set for such events
  bool treeSelectorDMtoFromUser(Set<String> pubkeys, { bool enableNotifications = true}) {

    if( event.eventData.kind != 4) {
      return false;
    }

    // if event is by user(s)
    if( pubkeys.contains(event.eventData.pubkey)) {
      if( enableNotifications) {
        event.eventData.isNotification = true;
      }
      return true;
    }

    // if its a DM to the user
    for(String pTag in event.eventData.pTags) {
      if( pubkeys.contains(pTag)) {
        return true;
      }
    }

    return false;
  } // end treeSelectorDMtoFromUser()

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

    // match event id if 
    bool eventIdMatches = false;
    if( word.length >= gMinEventIdLenInSearch && word.length <= 64) {
      if( event.eventData.id.substring(0, word.length) == word) {
        eventIdMatches = true;
      }
    }

    if( event.eventData.content.toLowerCase().contains(word) || eventIdMatches ) {
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
  bool treeSelector_hasNotifications() {

    bool hasNotifications = false;
    if( event.eventData.isNotification || event.eventData.newLikes.isNotEmpty) {
        hasNotifications = true;
    }

    bool childMatch = false;
    for( int i = 0; i < children.length; i++ ) {
      if( children[i].treeSelector_hasNotifications()) {
        childMatch = true;
        break;
      }
    }
    if( hasNotifications || childMatch) {
      return true;
    }

    return false;
  } // end treeSelector_hasNotifications()


  // clears all notifications; returns true always
  int treeSelector_clearNotifications() {
    int count = 0;

    if( event.eventData.isNotification) {
      event.eventData.isNotification = false;
      count = 1;
    }

    if( event.eventData.newLikes.isNotEmpty) {
      event.eventData.newLikes = {};
      count = 1;
    }

    for( int i = 0; i < children.length; i++ ) {
      count += children[i].treeSelector_clearNotifications();
    }

    return count;
  } // end treeSelector_clearNotifications()

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

/// ********************************************************************************************************************************
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

  Set<String>    encryptedGroupInviteIds; // event id's of gSecretMessageKind messages, which contain encrypted room secrets; channel users will look up here for the secret

  static String startMarkerStr = "" ;
  static String endMarkerStr = "";

  static const Set<int>   typesInEventMap = {0, 1, 3, 4, 5, 7, 40, 42, 140, 141, 142, gSecretMessageKind}; // 0 meta, 1 post, 3 follows list, 7 reactions

  Store(this.topPosts, this.allChildEventsMap, this.eventsWithoutParent, this.channels, this.encryptedChannels, this.directRooms, this.encryptedGroupInviteIds) {
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
          String roomName = "", roomAbout = "";
          if( json is String) {
            // in case there is no json in kind 40, we assume the string is room name
            roomName = json;
          } else {           
            if(  json.containsKey('name') ) {
              roomName = json['name']??"";
            }
            
            if( json.containsKey('about')) {
              roomAbout = json['about']??"";
            }
          }
          
          Channel? channel = getChannel(rooms, chatRoomId);
          if( channel != null) {
            if( channel.chatRoomName == "" ) {
              channel.chatRoomName = roomName;
            }
          } else {
 
            List<String> emptyMessageList = [];
            Channel room = Channel(chatRoomId, roomName, roomAbout, "", emptyMessageList, {}, ce.eventData.createdAt, enumRoomType.kind40);
            rooms.add( room);
          }
        } on Exception catch(e) {
          if( gDebug > 0) print("In From Event. Event type 40. Json Decode error for event id ${ce.eventData.id}. error = $e");
        }
      }
      return;

      case 42:
      {
        String channelId = ce.eventData.getChannelIdForKind4x();

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
      return;

      default:
        break;  
      } // end switch

    // create channels for location tag if it has location tag
    if(eKind == 1 && ce.eventData.getSpecificTag("location") != null ) {
      addLocationTagEventInChannel(ce.eventData, rooms, tempChildEventsMap);
    }
    
    if (eKind == 1 && ce.eventData.getTTags() != null) {
      addTTagEventInChannel(ce.eventData, rooms, tempChildEventsMap);
    }

  }

  // events with tag 'location' are added to their own public channel depending on value of tag. 
  static void addTTagEventInChannel(EventData eventData, List<Channel> rooms, Map<String, Tree> tempChildEventsMap) {

    List<String>? tTags = eventData.getTTags();
    if( tTags != null && tTags.isNotEmpty) {
      for( int i = 0; i < tTags.length; i++) {
        String chatRoomId = eventData.getChannelIdForTTagRoom(tTags[i]);
        Channel? channel = getChannel(rooms, chatRoomId);
        if( channel == null) {
          Channel room = Channel(chatRoomId, "#${tTags[i]}", "", "", [eventData.id], {}, eventData.createdAt, enumRoomType.RoomTTag);
          rooms.add( room);
        } else {
          // channel already exists
          channel.addMessageToRoom(eventData.id, tempChildEventsMap);
        }
      }
    }
  }

  // events with tag 'location' are added to their own public channel depending on value of tag. 
  static void addLocationTagEventInChannel(EventData eventData, List<Channel> rooms, Map<String, Tree> tempChildEventsMap) {

    String? location = eventData.getSpecificTag("location");
    if( location != null && location != "") {
      String chatRoomId = eventData.getChannelIdForLocationRooms();
      Channel? channel = getChannel(rooms, chatRoomId);
      if( channel == null) {
        Channel room = Channel(chatRoomId, gLocationNamePrefix + location, "", "", [eventData.id], {}, eventData.createdAt, enumRoomType.RoomLocationTag);
        rooms.add( room);
      } else {
        // channel already exists
        channel.addMessageToRoom(eventData.id, tempChildEventsMap);
      }
    }
  }

  static String? getEncryptedChannelIdFromSecretMessage( Event eventSecretMessage) {
    String evaluatedContent = eventSecretMessage.eventData.evaluatedContent;

    if( evaluatedContent.startsWith("App Encrypted Channels:")) {
      if(evaluatedContent.length == 288) {
        String channelId = evaluatedContent.substring(58, 58 + 64);

        if( channelId.length == 64) {
          return channelId;
        }
      }
    }
    return null;
  }

  /// Will create a entry in encryptedChannels ( if one does not already exist)
  /// Returns id of channel if one is created, null otherwise.
  /// 
  static String? createEncryptedRoomFromInvite( List<Channel> encryptedChannels, Map<String, Tree> tempChildEventsMap, Event eventSecretMessage) {

    String? temp140Id = getEncryptedChannelIdFromSecretMessage( eventSecretMessage);

    String event140Id = "";
    if( temp140Id == null) {
      return null;
    } else {
      event140Id = temp140Id;
    }

    Event? event140 = tempChildEventsMap[temp140Id]?.event;
    if( event140 != null) {
      
      Set<String> participants = {};
      for (var element in event140.eventData.pTags) { participants.add(element);}

      String chatRoomId = event140Id;
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
          Channel room = Channel(chatRoomId, roomName, roomAbout, "", [], participants, event140.eventData.createdAt, enumRoomType.kind140, event140.eventData.pubkey);
          encryptedChannels.add( room);
          //print("created enc room with id $event140Id");
          return chatRoomId;
        }
      } on Exception catch(e) {
        if( gDebug > 0) print("In From Event. Event type 140. Json Decode error for event id ${event140.eventData.id}. error = $e");
      }
    } // end if 140
    else {
        // create with lastUpdated == 0 so that later when/if 140 is seen then it can update this (only in that case and not otherwise)
        Channel room = Channel(event140Id, "", "", "", [], {}, 0, enumRoomType.kind140, eventSecretMessage.eventData.pubkey); 
        encryptedChannels.add( room);
        return event140Id;
    }
    return null;
  }

  static void handleEncryptedChannelEvent( Set<String> secretMessageIds, List<Channel> encryptedChannels, Map<String, Tree> tempChildEventsMap, Event event14x) {
      String eId = event14x.eventData.id;
      int    eKind = event14x.eventData.kind;

      switch(eKind) {

      // in only one case is 140 processed: when we got 104, at that time we creat channel ds, but later we get 140 which will have actual info about the channel
      // the infor will be name, about, pic, participant list; the created at will be 0 in such case when 104 created the channel data structure
      case 140:

        // update the participant list if the event already exists ( the room was likely creted with 104 invite, which did not have participant list)
        Set<String> participants = {};
        for (var element in event14x.eventData.pTags) { participants.add(element);}
        Channel? channel = getChannel(encryptedChannels, event14x.eventData.id);
        
        dynamic json = jsonDecode(event14x.eventData.content);

        if( channel != null && channel.lastUpdated == 0) {
          String roomName = "", roomAbout = "";
          if(  json.containsKey('name') ) {
            roomName = json['name']??"";
          }
          
          if( json.containsKey('about')) {
            roomAbout = json['about'];
          }
          
          channel.participants = participants;
          channel.chatRoomName = roomName;
          channel.about = roomAbout;
          channel.lastUpdated = event14x.eventData.createdAt;
        }
        break;

      case 141:
        Set<String> participants = {};
        for (var element in event14x.eventData.pTags) { participants.add(element);}
        
        String chatRoomId = event14x.eventData.getChannelIdForKind4x();
        if( chatRoomId.length != 64) {
          break;
        }

        try {
          dynamic json = jsonDecode(event14x.eventData.content);
          Channel? channel = getChannel(encryptedChannels, chatRoomId);
          if( channel != null) {
            // as channel entry already exists, then update its participants info, and name info
            if( channel.chatRoomName == "" && json.containsKey('name')) {
              channel.chatRoomName = json['name'];
            }

            if( channel.lastUpdated < event14x.eventData.createdAt) {
              if( participants.contains(userPublicKey) && !channel.participants.contains(userPublicKey) ) {
                //printInColor("\nReceived new invite to a new group with id: $chatRoomId\n", greenColor);
              }

              channel.participants = participants;
              channel.lastUpdated  = event14x.eventData.createdAt;
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
          if( gDebug > 0) print("In From Event. Event type 140. Json Decode error for event id ${event14x.eventData.id}. error = $e");
        }
        break;

      case 142:
        if( gSpecificDebug > 0) print("got kind 142 message. total number of encrypted channels: ${encryptedChannels.length}. event e tags ${event14x.eventData.eTags}");
        String channelId = event14x.eventData.getChannelIdForKind4x();

        if( channelId.length == 64) { // sometimes people may forget to give e tags or give wrong tags like #e
          Channel? channel = getChannel(encryptedChannels, channelId);
          if( channel != null) {
            channel.addMessageToRoom(eId, tempChildEventsMap);
          } else {
            if( gSpecificDebug > 0) print("could not get channel");
          }
        } else {
          // could not get channel id of message. 
          printWarning("---Could not get encryptd channel for message id ${event14x.eventData.id} got channelId : $channelId its len ${channelId.length}");
        }
        break;

      default:
        break;  
      } // end switch
  }

  // returns 1 if message was to the user; adds the secret message id to tempEncyrp... variable
  static int handleEncryptedGroupInvite(Set<String> tempEncryptedSecretMessageIds, Map<String, Tree> tempChildEventsMap, Event ce) {
      int    eKind = ce.eventData.kind;

      if( gSecretMessageKind != eKind || !isValidDirectMessage(ce.eventData)) {
        return 0;
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
          if( ce.eventData.evaluatedContent.isNotEmpty) numMessagesDecrypted++;
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
 
  static void handleInitialKind1(Tree tree, Map<String, Tree> tempChildEventsMap, 
                          List<Tree> topLevelTrees, List<String> tempWithoutParent, Set<String> eventIdsToFetch) {

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
            Event dummy = Event("","",  EventData(parentId,gDummyAccountPubkey, tree.event.eventData.createdAt, 1, "<Event is not of Kind 1>", [], [], [], [[]], {}), [""], "[json]");

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
            Event dummy = Event("","",  EventData(parentId,gDummyAccountPubkey, tree.event.eventData.createdAt, 1, "Missing event (not yet found on any relay)", [], [], [], [[]], {}), [""], "[json]");
            Tree dummyTopNode = Tree.withoutStore(dummy, []);
            dummyTopNode.children.add(tree);
            tempWithoutParent.add(tree.event.eventData.id); 
            eventIdsToFetch.add(parentId);
            topLevelTrees.add(dummyTopNode);
          }
        }
        else {
          if( gDebug > 0) {
            print("--------\ngot invalid parentId in fromEvents: $parentId");
            print("original json of event:\n${tree.event.originalJson}");
          }
        }
      }
    } else {
      // is not a parent, has no parent tag. then make it its own top tree, which will be done later in the calling function
    }
  }

  /// ********************************************************************************************************************************
  // @method create top level Tree from events. 
  // first create a map. then process each element in the map by adding it to its parent ( if its a child tree)
  factory Store.fromEvents(Set<Event> events) {
    if( events.isEmpty) {
    List<DirectMessageRoom> temp = [];

      return Store( [], {}, [], [], [], temp, {});
    }

    // create a map tempChildEventsMap from list of events, key is eventId and value is event itself
    Map<String, Tree> tempChildEventsMap = {};
    for (var event in events) { 
      // only add in map those kinds that are supported or supposed to be added ( 0 1 3 7 40)
      if( typesInEventMap.contains(event.eventData.kind)) {
        tempChildEventsMap[event.eventData.id] = Tree.withoutStore( event, []); 
      }
    }

    processDeleteEvents(tempChildEventsMap); // handle returned values perhaps later
    processReactions(events, tempChildEventsMap);

    // once tempChildEventsMap has been created, create connections between them so we get a tree structure from all these events.
    List<Tree>  topLevelTrees = [];// this will become the children of the main top node. These are events without parents, which are printed at top.
    List<String> tempWithoutParent = [];
    List<Channel> channels = [];
    List<Channel> encryptedChannels = [];
    List<DirectMessageRoom> tempDirectRooms = [];
    Set<String> eventIdsToFetch = {};
    Set<String> allEncryptedGroupInviteIds = {};

    tempChildEventsMap.forEach((newEventId, tree) {
      int eKind = tree.event.eventData.kind;

      // these are handled in another iteration ( cause first private messages need to be populated)
      if( eKind >= 140 && eKind <= 142 ) {
        return;
      }

      if(   eKind == 42 || eKind == 40 ){
        handleChannelEvents(channels, tempChildEventsMap, tree.event);
        return;
      }

      if( (eKind == 1 && tree.event.eventData.getSpecificTag("location") != null )
        || (eKind == 1 && tree.event.eventData.getTTags() != null)){
        handleChannelEvents(channels, tempChildEventsMap, tree.event);
        // same as above but no return cause these are processed as kind 1 too
      }

      if( eKind == 4) {
        handleDirectMessage(tempDirectRooms, tempChildEventsMap, tree.event);
        return;
      }

      if( eKind == gSecretMessageKind) {
        // add the event id to given structure if its a valid message
        if( isValidDirectMessage(tree.event.eventData, acceptableKind: gSecretMessageKind)) {
          //print("adding to enc list");
          allEncryptedGroupInviteIds.add(tree.event.eventData.id);
        }
        return;
      }

      if( eKind == 7) {
        processReaction(tree.event, tempChildEventsMap);
        return;
      }

      // if reacted to event is not in store, then add it to dummy list so it can be fetched
      if( tree.event.eventData.eTags.isNotEmpty && tree.event.eventData.eTags.last.isNotEmpty) {
        String reactedToId  = tree.event.eventData.eTags.last[0];
        if( !tempChildEventsMap.containsKey(reactedToId) && tree.event.eventData.createdAt > getSecondsDaysAgo(3)) {
          //print("liked event not found in store.");
          eventIdsToFetch.add(reactedToId);
        }
      }

      if( tree.event.eventData.id == gCheckEventId) {
        print("In fromEvent: got evnet id $gCheckEventId");
      }

      if( tree.event.eventData.kind != 1) {
        return;
      }

      // will handle kind 1 
      handleInitialKind1(tree, tempChildEventsMap, topLevelTrees, tempWithoutParent, eventIdsToFetch);

    }); // going over tempChildEventsMap and adding children to their parent's .children list

    // for pubkeys that don't have any kind 0 events ( but have other events), add then to global kind0 store so they can still be accessed
    tempChildEventsMap.forEach((key, value) {
        if( !gKindONames.containsKey(value.event.eventData.pubkey)) {
          gKindONames[value.event.eventData.pubkey] = UserNameInfo(null, null, null, null, null, null, null, null, null, null  );
        }
    });

    // allEncryptedGroupInviteIds has been created above 
    // now create encrypted rooms from that list which are just for the current user
    Set<String> usersEncryptedChannelIds = {};
    for (var secretEventId in allEncryptedGroupInviteIds) {
      Event? secretEvent = tempChildEventsMap[secretEventId]?.event;
      
      if( secretEvent != null) {
        secretEvent.eventData.TranslateAndDecryptGroupInvite();
        String? newEncryptedChannelId = createEncryptedRoomFromInvite( encryptedChannels,  tempChildEventsMap, secretEvent);
        if( newEncryptedChannelId != null) {
          usersEncryptedChannelIds.add(newEncryptedChannelId); // is later used so a request can be sent to fetch events related to this room
        }
      }
    }

    tempChildEventsMap.forEach((newEventId, tree) {
      int eKind = tree.event.eventData.kind;
      if( eKind >= 140 && eKind <= 142 ) {
        handleEncryptedChannelEvent(allEncryptedGroupInviteIds, encryptedChannels, tempChildEventsMap, tree.event);
      }
    });

    // add parent trees as top level child trees of this tree
    for( var tree in tempChildEventsMap.values) {
      if( tree.event.eventData.kind == 1 &&  tree.event.eventData.getParent(tempChildEventsMap) == "") {  // only posts which are parents
        topLevelTrees.add(tree);
      }
    }

    if(gDebug != 0) print("In Tree FromEvents: number of events without parent in fromEvents = ${tempWithoutParent.length}");

    // get dummy events and encryped channel create events
    sendEventsRequest(gListRelayUrls, eventIdsToFetch.union(usersEncryptedChannelIds));

    // get encrypted channel events,  get 141/142 by their mention of channels to which user has been invited through kind 104. get 140 by its event id.
    getMentionEvents(gListRelayUrls, usersEncryptedChannelIds, gLimitFollowPosts, getSecondsDaysAgo(gDefaultNumLastDays), "#e"); // from relay group 2

    // create Store
    return Store( topLevelTrees, tempChildEventsMap, tempWithoutParent, channels, encryptedChannels, tempDirectRooms, allEncryptedGroupInviteIds);
  } // end fromEvents()

   /// ********************************************************************************************************************************
   /* @processIncomingEvent inserts the relevant events into the tree and otherwise processes likes, delete events etc.
    *                        returns the id of the ones actually new so that they can be printed as notifications. 
    */
  Set<String> processIncomingEvent(Set<Event> newEventsToProcess) {
    if( gDebug > 0) log.info("In insertEvetnts: allChildEventsMap size = ${allChildEventsMap.length}, called for ${newEventsToProcess.length} NEW events");

    Set<String> newEventIdsSet = {};

    Set<String> dummyEventIds = {};

    // add the event to the main event store thats allChildEventsMap
    for (var newEvent in newEventsToProcess) { 
      
      if( newEvent.eventData.kind == 1 && newEvent.eventData.content.compareTo("Hello Nostr! :)") == 0 && newEvent.eventData.id.substring(0,3).compareTo("000") == 0) {
        continue; // spam prevention
      }

      if( allChildEventsMap.containsKey(newEvent.eventData.id)) {// don't process if the event is already present in the map
        continue;
      }

      //ignore bots
      if( [4, 42, 142].contains( newEvent.eventData.kind ) && gBots.contains(newEvent.eventData.pubkey)) {
        continue;
      }

      // handle reaction events and return if we could not find the reacted to. Continue otherwise to add this to notification set newEventIdsSet
      if( newEvent.eventData.kind == 7) {
        if( processReaction(newEvent, allChildEventsMap) == "") {
          if(gDebug > 0) print("In insertEvents: For new reaction ${newEvent.eventData.id} could not find reactedTo or reaction was already present by this reactor");
          continue;
        }
      }

      // handle delete events. return if its not handled for some reason ( like deleted event not found)
      if( newEvent.eventData.kind == 5) {
        processDeleteEvent(allChildEventsMap, newEvent);
        if(gDebug > 0) print("In insertEvents: For new deleteion event ${newEvent.eventData.id} could not process it.");
        continue;
      }

      if( newEvent.eventData.kind == 4) {
        if( !isValidDirectMessage(newEvent.eventData)) { // direct message not relevant to user are ignored; also otherwise validates the message that it has one p tag
          continue;
        }
      }

      if( newEvent.eventData.kind == 0) {
        processKind0Event(newEvent);
      }

      // only kind 0, 1, 3, 4, 5( delete), 7, 40, 42, 140, 142 events are added to map-store, return otherwise
      if( !typesInEventMap.contains(newEvent.eventData.kind) ) {
        continue;
      }

      // expand mentions ( and translate if flag is set) and then add event to main event map; 142 events are expanded later
      if( newEvent.eventData.kind != 142) {
        newEvent.eventData.translateAndExpandMentions( allChildEventsMap); // this also handles dm decryption for kind 4 messages, for kind 1 will do translation/expansion; 
      }

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
          continue;
        }
      }

      allChildEventsMap[newEvent.eventData.id] = Tree(newEvent, [], this);

      // add to new-notification list only if this is a recent event ( because relays may send old events, and we dont want to highlight stale messages)
      newEventIdsSet.add(newEvent.eventData.id);
     
    }
    
    // now go over the newly inserted event, and add it to the tree for kind 1 events, add 42 events to channels. rest ( such as kind 0, kind 3, kind 7) are ignored.
    for (var newId in newEventIdsSet) {
      Tree? newTree = allChildEventsMap[newId];
      if( newTree != null) {  // this should return true because we just inserted this event in the allEvents in block above

        switch(newTree.event.eventData.kind) {
          case 1:
            // only kind 1 events are added to the overall tree structure
            String parentId = newTree.event.eventData.getParent(allChildEventsMap);
            if( parentId == "") {
                // if its a new parent event, then add it to the main top parents 
                topPosts.add(newTree);
            } else {
                // if it has a parent , then add the newTree as the parent's child
                if( allChildEventsMap.containsKey(parentId)) {
                  allChildEventsMap[parentId]?.children.add(newTree);
                } else {
                  // create top unknown parent and then add it
                  Event dummy = Event("","",  EventData(parentId, gDummyAccountPubkey, newTree.event.eventData.createdAt, 1, "Missing event (not yet found on any relay)", [], [], [], [[]], {}), [""], "[json]");
                  Tree dummyTopNode = Tree.withoutStore(dummy, []);
                  dummyTopNode.children.add(newTree);
                  topPosts.add(dummyTopNode);

                  // add it to list to fetch it from relays
                  if( parentId.length == 64) {
                    dummyEventIds.add(parentId);
                  }                  
                }
            }

            // now process case where there is a tag which should put this kind 1 message in a channel
            String? location = newTree.event.eventData.getSpecificTag("location");
            if( location != null && location != "") {
              addLocationTagEventInChannel(newTree.event.eventData, channels, allChildEventsMap);
            }

            // now process case where there is a tag which should put this kind 1 message in a channel
            List<String>? tTags = newTree.event.eventData.getTTags();
            if( tTags != null && tTags != "") {
              addTTagEventInChannel(newTree.event.eventData, channels, allChildEventsMap);
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
            handleEncryptedChannelEvent(encryptedGroupInviteIds, encryptedChannels, allChildEventsMap, newTree.event);
            break;

          case gSecretMessageKind:
            if( isValidDirectMessage(newTree.event.eventData, acceptableKind: gSecretMessageKind)) {
              String ? temp = newTree.event.eventData.TranslateAndDecryptGroupInvite(); 
              if( temp != null) {
                encryptedGroupInviteIds.add(newTree.event.eventData.id);
                createEncryptedRoomFromInvite(encryptedChannels, allChildEventsMap, newTree.event);
                // TODO send event requests for 14x 
              }
            } else {
              //print("1. kind $gSecretMessageKind with id ${newTree.event.eventData.id} is not a valid direct message to user. ");
            }
            break;

          default: 
            break;
        }
      }
    }

    // get dummy events
    sendEventsRequest(gListRelayUrls, dummyEventIds);

    int totalTreeSize = 0;
    for (var element in topPosts) {totalTreeSize += element.count();}
    if(gDebug > 0) print("In end of insertEvents: allChildEventsMap size = ${allChildEventsMap.length}; mainTree count = $totalTreeSize");
    if(gDebug > 0)  print("Returning ${newEventIdsSet.length} new notification-type events, which are ${newEventIdsSet.length < 10 ? newEventIdsSet: " <had more than 10 elements>"} ");
    return newEventIdsSet;
  } // end insertEvents()

  /// ********************************************************************************************************************************
  /*
   * @printNotifications Add the given events to the Tree, and print the events as notifications
   *                     It should be ensured that these are only kind 1 events
   */
  List<int> printTreeNotifications(Set<String> newEventIdsSet) {

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

    if( countNotificationEvents == 0) {
      return [0,0,0];
    }
   
    List<Tree> topNotificationTree = []; // collect all top tress to display in this list. only unique tress will be displayed
    for (var eventID in newEventIdsSet) { 
      
      Tree ?t = allChildEventsMap[eventID];
      if( t == null) {
        // ignore if not in Tree. Should ideally not happen. TODO write warning otherwise
        if( gDebug > 0) print("In printNotifications: Could not find event $eventID in tree");
        continue;
      } else {
        if( isRelevantForNotification(t)) {
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
      }
    }

    // remove duplicate top trees
    Set ids = {};
    topNotificationTree.retainWhere((t) => ids.add(t.event.eventData.id));

    Store.reCalculateMarkerStr();

    // update this list, because it is internally used by printEvent
    gFollowList = getFollows(userPublicKey);

    List<int> ret = [0,0,0];
    for (var t in topNotificationTree) {
      Set<String> followList = getFollows(userPublicKey);
      bool selectorTrees_followActionsWithNotifications (Tree t) => 
                                                  t.treeSelectorUserPostAndLike( followList, enableNotifications: true);
      if( selectorTrees_followActionsWithNotifications(t)) {
        List<int> temp = Store.printTopPost(t, 0, DateTime(0));
        ret[0] += temp[0]; 
        ret[1] += temp[1]; 
        ret[2] += temp[2];
        //print("\n");
      }
    }

    return ret;
  }

// returns list , where first int is total Threads ( or top trees) printed, second is total events printed, and third is notifications printed
  static List<int> printTopPost(Tree topTree, int depth, DateTime newerThan, [int maxToPrint = gMaxEventsInThreadPrinted, bool userRelevant = false]) {
    stdout.write(Store.startMarkerStr);

    //if(topTree.event.eventData.isNotification) print('is notification');

    List<int> counts = topTree.printTree(depth, newerThan, true, 0, maxToPrint, userRelevant);
    counts[0] += 1; // for this top post 
    stdout.write(endMarkerStr);
    //print("In node printTopPost: ret =${counts}");
    return counts;
  }

  // will just traverse all trees in store  
  int traverseStoreTrees(fTreeSelector_int treeSelector) {
    int count = 0;
    for( int i = 0; i < topPosts.length; i++) {
      count += treeSelector(topPosts[i]);
    }
    return count;
  }

   /// ********************************************************************************************************************************
  /* The main print tree function. Calls the treeSelector() for every node and prints it( and its children), only if it returns true. 
   */
  List<int> printStoreTrees(int depth, DateTime newerThan, fTreeSelector treeSelector, [bool userRelevant = false, int maxToPrint = gMaxEventsInThreadPrinted]) {

    // update this list, because it is internally used by printEvent
    gFollowList = getFollows(userPublicKey);

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

    List<int> ret = [0,0,0];

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

      List<int> temp = printTopPost(topPosts[i], depth, newerThan, maxToPrint, userRelevant);
      ret[0] += temp[0]; 
      ret[1] += temp[1]; 
      ret[2] += temp[2];
      
    }

    int printedNumHours = DateTime.now().difference(newerThan).inHours;

    String strTime = "";
    if(printedNumHours > 24) {
      strTime = "${printedNumHours ~/ 24} days";
    } else {
      strTime = "$printedNumHours hours";
    }
    if( ret[0] > 0) {
      print("\nTotal threads printed: ${ret[0]} for last $strTime.");
    }

    //print("in node print all: ret = $ret");

    return ret;
  }
 
  int getNumChannels() {
    return channels.length;
  }

  Channel? getChannelFromId(List<Channel> chs, String channelId) {
    for( int i = 0; i < chs.length; i++) {
      if( chs[i].channelId.toLowerCase() == channelId.toLowerCase()) {
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

  /// @printAllChennelsInfo Print one line information about all channels, which are type 40 events ( class ChatRoom) and for 14x channels both; channelsToPrint is different for both
  /// 
  /// @param numRoomsOverview This many number of rooms should be printed. 
  int printChannelsOverview(List<Channel> channelsToPrint, int numRoomsOverview, fRoomSelector selector, var tempChildEventsMap , Set<String>? secretMessageIds) {

    channelsToPrint.sort(scrollableCompareTo);
    int numChannelsActuallyPrinted = 0;

    int startRoomIndex = 0, endRoomIndex = 0;

    if( numRoomsOverview == channelsToPrint.length) {
      startRoomIndex = 0;
      endRoomIndex = channelsToPrint.length;
    } else {
      if( numRoomsOverview < channelsToPrint.length ) {
        startRoomIndex = channelsToPrint.length - numRoomsOverview;
        endRoomIndex = channelsToPrint.length;
      } else {
        startRoomIndex = 0;
        endRoomIndex = channelsToPrint.length;
      }
    }

    print("\n\n");
    printUnderlined("Channel Name                       id                Num of Messages     Latest Message                       ");
    for(int j = startRoomIndex; j < endRoomIndex; j++) {

      //stdout.write("channel type: " + channelsToPrint[j].roomType.toString());

      if( channelsToPrint[j].participants.isNotEmpty &&  !channelsToPrint[j].participants.contains(userPublicKey)) {
        continue;
      }

      if( !selector(channelsToPrint[j]) ) {
        continue;
      }

      String name = "";
      String id = "";
      if( channelsToPrint[j].channelId.contains('#location')) {
        id = myPadRight(channelsToPrint[j].channelId, 16);
      } else if ( channelsToPrint[j].channelId.contains(" #t")){
        id = myPadRight(channelsToPrint[j].channelId, 16);  
      } else {
        String temp = channelsToPrint[j].channelId.substring(0, channelsToPrint[j].channelId.length > 6? 6: channelsToPrint[j].channelId.length);
        id = myPadRight( temp, 16);
      }

      if( channelsToPrint[j].chatRoomName != "") {
        name = channelsToPrint[j].chatRoomName;
      }

      int numMessages = channelsToPrint[j].getNumValidMessages();
      stdout.write("$name ${getNumSpaces(32-name.length)}  $id  $numMessages${getNumSpaces(20- numMessages.toString().length)}"); 
      numChannelsActuallyPrinted++;
      List<String> messageIds = channelsToPrint[j].messageIds;
      for( int i = messageIds.length - 1; i >= 0; i--) {
        if( allChildEventsMap.containsKey(messageIds[i])) {
          Event? e = allChildEventsMap[messageIds[i]]?.event;
          if( e!= null) {
            if( !(e.eventData.kind == 142 && e.eventData.content == e.eventData.evaluatedContent)) {
              stdout.write(e.eventData.getAsLine(tempChildEventsMap, secretMessageIds, channelsToPrint));
              break; // print only one event, the latest one
            }
          }
        }
      }
      print("");
    }

    print("");
    print("Showing $numChannelsActuallyPrinted/${channelsToPrint.length} channels\n");

    return numChannelsActuallyPrinted;
  }

  void printChannel(Channel room, Map<String, Tree>? tempChildEventsMap, Set<String>? inviteMessageIds, List<Channel>? encryptedChannels, [int page = 1])  {
    if( page < 1) {
      if( gDebug > 0) log.info("In printChannel got page = $page");
      page = 1;
    }

    room.printOnePage(allChildEventsMap, inviteMessageIds, encryptedChannels, page);
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
    for (var participant in room.participants) {
      
      if( i != 0) {
        stdout.write(', ');
      }
      String pName = getAuthorName(participant);
      printInColor(pName, gCommentColor);
      i++;
    }

  }

  Set<String> getExactMatches(List<Channel> listChannels, channelId) {
    Set<String> matches = {};

    for(int i = 0; i < listChannels.length; i++) {
      Channel room = listChannels[i];

      // exact match name
      if( room.chatRoomName.toLowerCase() == channelId.toLowerCase()) {
        matches.add(room.channelId);
      }

      // exact match channel id
      if( room.channelId.toLowerCase() == channelId.toLowerCase()) {
        matches.add(room.channelId);
      }
    }
    return matches;
  }

  // works for both 4x and 14x channels
  // shows the given channelId, where channelId is prefix-id or channel name as mentioned in room.name. returns full id of channel.
  // looks for channelId in id first, then in names. 
  String showChannel(List<Channel> listChannels, String channelId, Map<String, Tree>? tempChildEventsMap, Set<String>? inviteMessageIds, List<Channel>? encryptedChannels, [int page = 1]) {
    if( channelId.length > 64 ) {
      return "";
    }

    // first check channelsId's, in case user has sent a channelId itself
    Set<String> fullChannelId = getExactMatches(listChannels, channelId);

    if( fullChannelId.length != 1) {
      for(int i = 0; i < listChannels.length; i++) {
        // do partial match in channel room name
        Channel room = listChannels[i];
        if( room.chatRoomName.length >= channelId.length) {
          if( room.chatRoomName.substring(0, channelId.length).toLowerCase() == channelId.toLowerCase() ) {
            // otherwise add it to list
            fullChannelId.add(room.channelId.toLowerCase());
          }
        }

        // do partial match in ids
        if( listChannels[i].channelId.length >= channelId.length) {
          if(  listChannels[i].channelId.substring(0, channelId.length).toLowerCase() == channelId.toLowerCase() ) {
            // otherwise add it to list
            fullChannelId.add(room.channelId.toLowerCase());
          }
        }
      } // end for
    }

    if( fullChannelId.length == 1) {
      Channel? room = getChannel( listChannels, fullChannelId.first);
      if( room != null) {

        if( room.roomType == enumRoomType.kind140) {
          // enforce the participants-only rule
          if( !room.participants.contains(userPublicKey)) {
            print("\nYou are not not a participant in this encrypted room, where the participant list is: ${room.participants}");
            print("room name: ${room.chatRoomName}");
            return "";
          }

          printEncryptedChannelInfo(room);
          stdout.write("\n\n");
        }
        printChannel(room, tempChildEventsMap, inviteMessageIds, encryptedChannels, page);
      }
      return fullChannelId.first;
    } else {
      if( fullChannelId.isEmpty) {
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

  /// @printDirectRoomInfo Print one line information about chat rooms
  int printDirectRoomsOverview(fRoomSelector roomSelector, int numRoomsOverview, var tempChildEventsMap) { 
    directRooms.sort(scrollableCompareTo);

    int numNotificationRooms = 0;
    for( int j = 0; j < directRooms.length; j++) {
      if( roomSelector(directRooms[j])) {
        numNotificationRooms++;
      }
    }

    // even if num rooms is zero, we will show the heading when its show all rooms
    if( numNotificationRooms == 0 && roomSelector != showAllRooms) { 
      return 0;
    }

    if( numNotificationRooms > numRoomsOverview) {
      numNotificationRooms = numRoomsOverview;
    }

    int numRoomsActuallyPrinted = 0;
    stdout.write("\n");
    stdout.write("\n\n");
    
    printUnderlined("From                                       Pubkey   Num of Messages   Latest Message                       ");

    int startRoomIndex = 0, endRoomIndex = 0;

    if( numRoomsOverview == directRooms.length) {
      startRoomIndex = 0;
      endRoomIndex = directRooms.length;
    } else {
      if( numRoomsOverview < directRooms.length ) {
        startRoomIndex = directRooms.length - numRoomsOverview;
        endRoomIndex = directRooms.length;
      } else {
        startRoomIndex = 0;
        endRoomIndex = directRooms.length;
      }
    }

    int iNotification = 0; // notification counter
    for( int j = startRoomIndex; j < endRoomIndex; j++) {
      if( !roomSelector(directRooms[j])) {
        continue;
      }

      // print only that we have been asked for
      if( iNotification++ > numNotificationRooms) {
        break;
      }

      DirectMessageRoom room = directRooms[j];
      String id = room.otherPubkey.substring(0, 6);
      String name = getAuthorName(room.otherPubkey);

      void markAllRead (Event e) => e.eventData.isNotification = false;
      room.visitAllMessages(this, markAllRead);

      int numMessages = room.messageIds.length;
      stdout.write("$name ${getNumSpaces(32-name.length)}          $id   $numMessages${getNumSpaces(18- numMessages.toString().length)}"); 

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

    print("\nShowing $numNotificationRooms/${directRooms.length} direct rooms.");

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
        if( isValidHexPubkey(lookedUpName.first)) { // in case the pubkey is valid and we have seen the pubkey in global author list, create new room
          print("Could not find a conversation or room with the given id. Creating one with ${lookedUpName.first}");
          DirectMessageRoom room = createDirectRoom( directRoomId);
          room.printDirectMessageRoom(this, page);
          return directRoomId;
        }
      }
    } else {
      if( lookedUpName.isNotEmpty) {
       printWarning("Got more than one public id for the name given, which are: ");
       for(String pubkey in lookedUpName) {
        print("${getAuthorName(pubkey)} - $pubkey, ");
       }
      }
      else { // in case the given id is not present in our global list of usernames, create new room for them 
        if( isValidHexPubkey(directRoomId)) {
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

  // threads where the user and follows have involved themselves are returnes as true ( relevant)
  bool isRelevantForNotification(Tree tree) {
    if(   tree.treeSelectorUserPostAndLike(gFollowList.union(gDefaultFollows).union({userPublicKey}), 
                                           enableNotifications: false,
                                           checkChildrenToo: false)
       || tree.treeSelectorDMtoFromUser({userPublicKey},
                                         enableNotifications: false)) {
      return true;
    }

    return false;
  }


  // returns true if the given event should be saved in file
  bool isRelevantForFileSave(Tree tree) {
    if( tree.event.userRelevant == true) {
      return true;
    }

    // threads where the user and follows have involved themselves are returnes as true ( relevant)
    if(   tree.treeSelectorUserPostAndLike(gFollowList.union(gDefaultFollows).union({userPublicKey}), enableNotifications: false) 
       || tree.treeSelectorDMtoFromUser({userPublicKey}, enableNotifications: false)
       || tree.treeSelectorUserReplies(gFollowList)
       || tree.treeSelectorUserMentioned({userPublicKey}) ) {
      
          return true;
    }

    // save all group events for now 
    var kind = tree.event.eventData.kind;
    if( kind == 40 || kind == 41 || kind == 42 ) {
      return true;
    }

    return false;
  }

  // Write the tree's events to file as one event's json per line
  Future<void> writeEventsToFile(String filename) async {

    // this variable will be used later; update it if needed
    if( gFollowList.isEmpty) {
      gFollowList = getFollows(userPublicKey);
    }

    if( gDebug > 0) print("opening $filename to write to.");
    try {
      final File file         = File(filename);
      
      if( gOverWriteFile) {
        await  file.writeAsString("", mode: FileMode.write).then( (file) => file);
      }

      int        eventCounter = 0;
      String     nLinesStr    = "";
      int        countPosts   = 0;

      const int  numLinesTogether = 100; // number of lines to write in one write call
      int        linesWritten = 0;
      for( var tree in allChildEventsMap.values) {

        if(   tree.event.eventData.isDeleted                      // dont write those deleted
           || gDummyAccountPubkey == tree.event.eventData.pubkey  // dont write dummy events
           || tree.event.originalJson.length < 10) { 
          continue; 
        }

        if( gOverWriteFile == false) {
          if( tree.event.readFromFile) { // ignore those already in file; only the new ones are writen/appended to file
            continue;
          }
        }

        if( !isRelevantForFileSave(tree)) {
          continue;
        }

        String temp = tree.event.originalJson.trim();
        String line = "$temp\n";
        nLinesStr += line;
        eventCounter++;
        if( tree.event.eventData.kind == 1) {
          countPosts++;
        }
        //if( temp.length < 10) print('len < 10');
        if( eventCounter % numLinesTogether == 0) {
          await  file.writeAsString(nLinesStr, mode: FileMode.append).then( (file) => file);
          //print("nLineStr len = ${nLinesStr.length}");
          nLinesStr = "";
          linesWritten += numLinesTogether;
        }
      } // end for

      if(  eventCounter > linesWritten) {
        await  file.writeAsString(nLinesStr, mode: FileMode.append).then( (file) => file);
        nLinesStr = "";
      }

      if(gDebug > 0) log.info("finished writing eventCounter = $eventCounter.");
      print("Appended $eventCounter new events to file \"$gEventsFilename\" of which $countPosts are posts.");
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
  String getTagStr(String replyToId, String clientName, [bool addAllP = false, Set<String>? extraTags]) {
    clientName = (clientName == "")? "nostr_console": clientName; // in case its empty 

    //print("extraTags = $extraTags");
    String otherTags = "";

    if( extraTags != null)
    for( String extraTag in extraTags) {
      if( otherTags.isNotEmpty) {
        otherTags += ",";
      }
      otherTags += '["t","$extraTag"]';
    }

    if( gWhetherToSendClientTag) {
      if( otherTags.isNotEmpty) {
        otherTags += ",";
      }
      otherTags += '["client","$clientName"]';
    }

    if( gUserLocation != "") {
      if( otherTags.isNotEmpty) {
        otherTags += ",";
      }
      otherTags += '["location","$gUserLocation"]';
    }

    //print("otherTags = $otherTags");
    if( replyToId.isEmpty) {
      return otherTags.isNotEmpty ? otherTags: '[]';
    }

    String strTags = otherTags ;

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
    if( latestEventId.isEmpty && replyToId.length != 64 && replyToId.isNotEmpty) {
      return "";
    }

    // found the id of event we are replying to; now gets its top event to set as root, if there is one
    if( latestEventId.isNotEmpty) {
      String? pTagPubkey = allChildEventsMap[latestEventId]?.event.eventData.pubkey;
      if( pTagPubkey != null) {
        if( strTags.isNotEmpty) {
          strTags += ",";
        }
        strTags += '["p","$pTagPubkey"]';
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
          if( strTags.isNotEmpty) {
            strTags += ",";
          }
          strTags +=  '["e","$rootEventId","","root"]';
        }
      }

      if( strTags.isNotEmpty) {
        strTags += ",";
      }
      strTags +=  '["e","$latestEventId","$relay","reply"]';
    }

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
    
    if( channel.roomType == enumRoomType.kind40 || channel.roomType == enumRoomType.kind140) {
      strTags +=  '["e","$channelId"]';
    } else if( channel.roomType == enumRoomType.RoomLocationTag) {
      String channelId = channel.getChannelId();
      String location = channelId.substring(0, channelId.length - gLocationTagIdSuffix.length);
      strTags += '["location","$location"]';
    } else if (channel.roomType == enumRoomType.RoomTTag) {
      String channelId = channel.getChannelId();
      String tag = channelId.substring(0, channelId.length - gTTagIdSuffix.length);
      strTags += '["t","$tag"]';
    }

    strTags += ',["client","$clientName"]' ;
    return strTags;
  }

  /*
   * @getTagsFromEvent Searches for all events, and creates a json of e-tag type which can be sent with event
   *                   Also adds 'client' tag with application name.
   * @parameter replyToId First few letters of an event id for which reply is being made
   */
  String getTagStrForChannelReply(Channel channel, String replyToId, String clientName, [bool addAllP = false]) {
    String channelId = channel.channelId;

    String strTags = "";

    if( channel.roomType == enumRoomType.RoomLocationTag) {
      String channelId = channel.getChannelId();
      String location = channelId.substring(0, channelId.length - gLocationTagIdSuffix.length);
      strTags += '["location","$location"]';
    } else if (channel.roomType == enumRoomType.RoomTTag) {
      String channelId = channel.getChannelId();
      String tag = channelId.substring(0, channelId.length - gTTagIdSuffix.length);
      strTags += '["t","$tag"]';
    } else {
      strTags +=  '["e","$channelId"]';
    }

    clientName = (clientName == "")? "nostr_console": clientName; // in case its empty 
    if( replyToId.isEmpty) {
      return ',["client","$clientName"]';
    }

    strTags += ',["client","$clientName"]' ;

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

    if( latestEventId.isEmpty && replyToId.length != 64 && replyToId.isNotEmpty) {
      printWarning('Could not find the given id: $replyToId. Sending a regular message.');
    }

    // found the id of event we are replying to; now gets its top event to set as root, if there is one
    if( latestEventId.isNotEmpty) {
      String? pTagPubkey = allChildEventsMap[latestEventId]?.event.eventData.pubkey;
      String relay = getRelayOfUser(userPublicKey, pTagPubkey??"");
      relay = (relay == "")? defaultServerUrl: relay;
      strTags +=  ',["e","$latestEventId","","reply"]';

      if( pTagPubkey != null) {
        strTags += ',["p","$pTagPubkey"]';
      }

      // add root for kind 1 in rooms
      if( [enumRoomType.RoomLocationTag, enumRoomType.RoomTTag].contains( channel.roomType) ) {
        Tree? replyTree = allChildEventsMap[latestEventId];
        if( replyTree != null) {
          Tree rootTree = getTopTree(replyTree);
          String rootEventId = rootTree.event.eventData.id;
          strTags +=  ',["e","$rootEventId","","root"]';
        }
      }
    }

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
            if( contactList[i].contactPubkey == pubkey) {
              followers.add(otherPubkey);
              return;
            }
          }
        }
    });

    return followers;
  }

  // finds all your followers, and then finds which of them follow the otherPubkey
  void printMutualFollows(Event contactEvent, String otherName) {
    String otherPubkey = contactEvent.eventData.pubkey;
    String otherName = getAuthorName(otherPubkey);


    bool isFollow = false;
    int  numSecond = 0; // number of your follows who follow the other

    List<String> mutualFollows = []; // displayed only if user is checking thier own profile
    int selfNumContacts =  0;

    Event? selfContactEvent = getContactEvent(userPublicKey);

    if( selfContactEvent != null) {
      List<Contact> selfContacts = selfContactEvent.eventData.contactList;
      selfContacts.sort();
      selfNumContacts = selfContacts.length;
      for(int i = 0; i < selfContacts.length; i ++) {
        // check if you follow the other account
        if( selfContacts[i].contactPubkey == otherPubkey) {
          isFollow = true;
        }
        // count the number of your contacts who know or follow the other account
        List<Contact> followContactList = [];
        Event? followContactEvent = getContactEvent(selfContacts[i].contactPubkey);
        if( followContactEvent != null) {
          followContactList = followContactEvent.eventData.contactList;
          for(int j = 0; j < followContactList.length; j++) {
            if( followContactList[j].contactPubkey == otherPubkey) {
              mutualFollows.add(getAuthorName(selfContacts[i].contactPubkey));
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
        mutualFollows.sort();
        for (var name in mutualFollows) { stdout.write("$name, ");}
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
      for (var tag in deleterEvent.eventData.tags) { 
        if( tag.length < 2) {
          continue;
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
      }
    } // end if
    return deletedEventIds;
  } // end processDeleteEvent

  static List<String> processDeleteEvents(Map<String, Tree> tempChildEventsMap) {
    List<String> deletedEventIds = [];
    tempChildEventsMap.forEach((key, tree) {
      Event deleterEvent = tree.event;
      if( deleterEvent.eventData.kind == 5) {
          List<String> tempIds = processDeleteEvent(tempChildEventsMap, deleterEvent);
          for (var tempId in tempIds) { deletedEventIds.add(tempId); }
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

    if(  gDebug > 0 && event.eventData.id == gCheckEventId) {
      print("in processReaction: 0 got reaction $gCheckEventId");
    }

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

      // set isHidden for reactedTo if it exists in map
      if( comment == "!" ) {
        if( event.eventData.pubkey == userPublicKey) {
          // is a hide reaction by the user; set reactedToid as hidden
          tempChildEventsMap[reactedToId]?.event.eventData.isHidden = true;
          return reactedToId;
        } else {
          // is hidden reaction by someone else; do nothing then
          return "";
        }
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

// sorter function that looks at the latest event in the whole tree including the/its children
int sortTreeByItsTime(Tree a, Tree b) {
  int aTime = a.event.eventData.createdAt;
  int bTime = b.event.eventData.createdAt;

  if(aTime < bTime) {
    return -1;
  } else {
    if( aTime == bTime) {
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
      return Store([], {}, [], [], [], temp, {});
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
    for (var event in events) {
      processKind0Event(event);
    }

    // process kind 3 events which is contact list. Update global info about the user (with meta data) 
    for (var event in events) {
      processKind3Event(event);
    }

    // create tree from events
    Store node = Store.fromEvents(events);

    // translate and expand mentions 
    events.where((element) => [1, 42].contains(element.eventData.kind)).forEach( (event) =>   event.eventData.translateAndExpandMentions( node.allChildEventsMap));
    
    // has been done in fromEvents
    //events.where((element) => [gSecretMessageKind].contains(element.eventData.kind)).forEach( (event) =>   event.eventData.TranslateAndDecryptGroupInvite( ));;
    events.where((element) => element.eventData.kind == 142).forEach( (event) => event.eventData.translateAndDecrypt14x(node.encryptedGroupInviteIds, node.encryptedChannels, node.allChildEventsMap));

    return node;
}

//   returns the id of event since only one p is expected in an event ( for future: sort all participants by id; then create a large string with them together, thats the unique id for now)
String getDirectRoomId(EventData eventData) {

  List<String> participantIds = [];
  for (var tag in eventData.tags) { 
    if( tag.length < 2) {
      continue;
    }

      if( tag[0] == 'p') {
        participantIds.add(tag[1]);
      }
  }

  participantIds.sort();
  String uniqueId = "";
  for (var element in participantIds) {uniqueId += element;} // TODO ensure its only one thats added s

  // send the other persons pubkey as identifier 
  if( eventData.pubkey == userPublicKey) {
    return uniqueId;
  } else { 
    return eventData.pubkey;
  }
}
