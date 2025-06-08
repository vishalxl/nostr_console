
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/utils.dart';

// is set intermittently by functions. and used as required. Should be kept in sync as the kind 3 for user are received. 
Set<String> gFollowList = {};

// From the list of events provided, lookup the lastst contact information for the given user/pubkey
Event? getContactEvent(String pubkey) {

    // get the latest kind 3 event for the user, which lists his 'follows' list
    if( gKindONames.containsKey(pubkey)) {
      Event? e = (gKindONames[pubkey]?.latestContactEvent);
      return e;
    }

    return null;
}

// returns all follows
Set<String> getFollows(String pubkey) {
  Set<String> followPubkeys = {};

  Event? profileContactEvent = getContactEvent(pubkey);
  if( profileContactEvent != null) {
    for (var x in profileContactEvent.eventData.contactList) {
      followPubkeys.add(x.contactPubkey);
    }
  }

  return followPubkeys;
}

// returns all mutual follows
Set<String> getMutualFollows(String pubkey) {
  Set<String> mutualFollowPubkeys = {};

  Event? profileContactEvent = getContactEvent(pubkey);
  if( profileContactEvent != null) {
    for (var x in profileContactEvent.eventData.contactList) { // go over each follow
      Event? followContactEvent = getContactEvent(x.contactPubkey);
      if( followContactEvent != null) {
        for (var y in followContactEvent.eventData.contactList) { // go over the follow's friend list
          mutualFollowPubkeys.add(x.contactPubkey);
          break;
        }
      }
    }
  }

  //print("number of mutual follows being returned:  ${mutualFollowPubkeys.length}");
  return mutualFollowPubkeys;
}

Set<String>  getUserChannels(Set<Event> userEvents, String userPublicKey) {
  Set<String> userChannels = {};

  for (var event in userEvents) {
    if( event.eventData.pubkey == userPublicKey) {
      if( [42, 142].contains( event.eventData.kind) ) {
        String channelId = event.eventData.getChannelIdForKind4x();
        if( channelId.length == 64) {
          userChannels.add(channelId);
        }
      } else if([40,41,140,141].contains(event.eventData.kind)) {
        userChannels.add(event.eventData.id);
      }
    }
  }

  return userChannels;
}

void addToHistogram(Map<String, int> histogram, List<String> pTags) {
  Set tempPtags = {};
  pTags.retainWhere((x) =>  tempPtags.add(x));

  for(int i = 0; i < pTags.length; i++ ) {
    String pTag = pTags[i];
    if( histogram.containsKey(pTag)) {
      int? val = histogram[pTag];
      if( val != null) {
        histogram[pTag] = ++val;
      } else {
      }
    } else {
      histogram[pTag] = 1;
    }
  }
  //return histogram;
}

// return the numMostFrequent number of most frequent p tags ( user pubkeys) in the given events
Set<String> getpTags(Set<Event> events, int numMostFrequent) {
  List<HistogramEntry> listHistogram = [];
  Map<String, int>   histogramMap = {};
  for(var event in events) {
    addToHistogram(histogramMap, event.eventData.pTags);
  }

  histogramMap.forEach((key, value) {listHistogram.add(HistogramEntry(key, value));/* print("added to list of histogramEntry $key $value"); */});
  listHistogram.sort(HistogramEntry.histogramSorter);
  List<String> ptags = [];
  for( int i = 0; i < listHistogram.length && i < numMostFrequent; i++ ) {
    ptags.add(listHistogram[i].str);
  }

  return ptags.toSet();
}

Set<String> getOnlyUserEvents(Set<Event> initialEvents, String userPubkey) {
  Set<String> userEvents = {};
  for (var event in initialEvents) {
    if( event.eventData.pubkey == userPubkey) {
      userEvents.add(event.eventData.id);
    }
  }
  return userEvents;
}

