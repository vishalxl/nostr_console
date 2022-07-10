
int    keyLenPrinted    = 6;
String defaultServerUrl = 'wss://nostr-pub.wellorder.net';


class Contact {
  String id;
  String relay;
  String name;
  Contact(this.id, this.relay, this.name);
  factory Contact.fromJson(dynamic json) {
    return Contact(json[1] as String, json[2] as String, json[3]);
  }
}

class EventData {
  String id;
  String pubkey;
  String content;
  int    createdAt;
  int    kind;
  List<Contact> contactList = [];
  
  EventData(this.id, this.pubkey, this.content, this.createdAt, this.kind, this.contactList);
  
  factory EventData.fromJson(dynamic json) {
    List<Contact> contactList = [];

    // NIP 02: if the event is a contact list type, then populate contactList
    if(json['kind'] == 3) {
      var tags = json['tags'];
      //print(tags);
      var numTags = tags.length;
      for( int i = 0; i < numTags; i++) {
        
        var tag = tags[i];
        var n = tag.length;
        String server = defaultServerUrl;
        if( n >=3 ) {
          server = tag[2].toString();           
        }
        Contact c = Contact(tag[1] as String, server, 3.toString());
        contactList.add(c);
      }
     
    }

    // return
    return EventData(json['id'] as String, 
                     json['pubkey'] as String, 
                     json['content'] as String, 
                     json['created_at'] as int, 
                     json['kind'] as int,
                     contactList);
  }
  @override
  String toString() {
    if( id == "non") {
      return '';
    }

    String max3(String v) => v.length > 3? v.substring(0,3) : v.substring(0, v.length);
    DateTime dTime = DateTime.fromMillisecondsSinceEpoch(createdAt *1000);

    return '-------+\nid     : ${max3(id)} \nAuthor : ${max3(pubkey)}\nTime   : $dTime\nKind   : $kind\nMessage: $content\n';
  }
}


class Event {
  String event;
  String id;
  EventData eventData;
  Event(this.event, this.id, this.eventData);
  factory Event.fromJson(dynamic json) {
    if( json.length < 3) {
      String e = "";
      e = json.length > 1? json[0]: "";
      return Event(e,"",EventData("non","","", 0, 0, []));
    }

    return Event(json[0] as String, json[1] as String,  EventData.fromJson(json[2]) );
  }

  @override 
  String toString() {
    return '$eventData';
  }
}

int ascendingTime(Event a, Event b) {
  if(a.eventData.createdAt < b.eventData.createdAt) {
    return 0;
  }

  return 1;
}

void printEvents(List<Event> events) {
    events.sort(ascendingTime);
    for( int i = 0; i < events.length; i++) {
      if( events[i].eventData.kind == 1) {
        print('${events[i]}');
      }
    }
}



/*  
NIP 02
{
  "kind": 3,
  "tags": [
    ["p", "91cf9..4e5ca", "wss://alicerelay.com/", "alice"],
    ["p", "14aeb..8dad4", "wss://bobrelay.com/nostr", "bob"],
    ["p", "612ae..e610f", "ws://carolrelay.com/ws", "carol"]
  ],
  "content": "",
  ...other fields


Example Event returned
[
  "EVENT",
  "latest",
  {
    "id": "5e4ca472540c567ba877ab232fa77c0801f4b2121756ed21d827e749b5074ac7",
    "pubkey": "47bae3a008414e24b4d91c8c170f7fce777dedc6780a462d010761dca6482327",
    "created_at": 1657316002,
    "kind": 1,
    "tags": [
      [
        "p",
        "80482e60178c2ce996da6d67577f56a2b2c47ccb1c84c81f2b7960637cb71b78",
        "wss://relay.damus.io"
      ],
      [
        "e",
        "241f1108b3616eb4b3cfb9fdbab29d7f8d291fda9db84a79f2491271e2f6122e"
      ],
      [
        "e",
        "b3349c4de2ff7a672c564e6fd147bc2d5dd71b525f96f35f8ede75138136c867",
        "wss://nostr-pub.wellorder.net"
      ]
    ],
    "content": "Not even surprised it's a thing https://coinmarketcap.com/currencies/lol/",
    "sig": "abebbc96a8a922f06ca2773c59521d03b6a8dd5597ae5654afc2d49e03a1e9c193729ff60473f837edc526e41c94f3de8a328c20bf9cff5353cb9c409a982461"
  }
]


  factory EventData.fromStr(String str) {
    var json = jsonDecode(str);
    return EventData(json['id'] as String, json['pubkey'] as String, json['content'] as String);
  }
 */