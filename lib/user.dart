
import 'package:nostr_console/event_ds.dart';
import 'package:nostr_console/settings.dart';
import 'package:nostr_console/utils.dart';

// From the list of events provided, lookup the lastst contact information for the given user/pubkey
Event? getContactEvent(String pubkey) {

    // get the latest kind 3 event for the user, which lists his 'follows' list
    if( gKindONames.containsKey(pubkey)) {
      Event? e = (gKindONames[pubkey]?.latestContactEvent)??null;
      return e;
    }

    return null;
}

Set<String>  getUserChannels(Set<Event> userEvents, String userPublicKey) {
  Set<String> userChannels = {};

  userEvents.forEach((event) {
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
  });

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
  initialEvents.forEach((event) {
    if( event.eventData.pubkey == userPubkey) {
      userEvents.add(event.eventData.id);
    }
  });
  return userEvents;
}