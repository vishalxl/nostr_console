
// for debugging
String gCheckEventId = "a4479de655094679cdfb10f347521aa58f24717cdc5ddba89fb346453a8a99ed";


const int numWaitSeconds = 3000;

// global counters of total events read or processed
int numFileEvents = 0, numUserEvents = 0, numFeedEvents = 0, numOtherEvents = 0;

List<String> gListRelayUrls = [defaultServerUrl,
                              "wss://nostr-verified.wellorder.net", 
                              "wss://nostr-relay.wlvs.space", 
                              "wss://nostr-pub.wellorder.net", 
                              "wss://relay.damus.io"];


// name of executable
const String exename = "nostr_console";
const String version = "0.0.6";

// well known disposable test private key
const String gDefaultPrivateKey = "9d00d99c8dfad84534d3b395280ca3b3e81be5361d69dc0abf8e0fdf5a9d52f9";
const String gDefaultPublicKey  = "e8caa2028a7090ffa85f1afee67451b309ba2f9dee655ec8f7e0a02c29388180";
String userPrivateKey = gDefaultPrivateKey;
String userPublicKey  = gDefaultPublicKey;

const int  gMinValidTextWidth = 60; // minimum text width acceptable
const int  gDefaultTextWidth = 120; // default text width
int        gTextWidth = gDefaultTextWidth; // is changed by --width option
const int  gSpacesPerDepth = 8;     // constant
int        gNumLeftMarginSpaces = 0;// this number is modified in main 
String     gAlignment = "center";   // is modified in main if --align argument is given
const int  gapBetweenTopTrees = 1;

// after depth of maxDepthAllowed the thread is re-aligned to left by leftShiftThreadBy
const int  gMinimumDepthAllowed = 2;
const int  gMaximumDepthAllowed  = 12;
const int  gDefaultMaxDepth     = 4;
int        maxDepthAllowed      = gDefaultMaxDepth;
const int  leftShiftThreadsBy   = 2;

// 33 yellow, 31 red, 34 blue, 35 magenta. Add 60 for bright versions. 
const String commentColor = "\x1B[32m"; // green
const String notificationColor = "\x1b[36m"; // cyan
const String warningColor = "\x1B[31m"; // red
const String colorEndMarker = "\x1B[0m";

//String defaultServerUrl = 'wss://relay.damus.io';
const String nostrRelayUnther = 'wss://nostr-relay.untethr.me';
String defaultServerUrl = nostrRelayUnther;

// dummy account pubkey
const String gDummyAccountPubkey = "Non";

// By default the threads that were started in last one day are shown
// this can be changed with 'days' command line argument
int gNumLastDays     = 1; 

// global user names from kind 0 events, mapped from public key to user name
Map<String, String> gKindONames = {}; 

// global reactions entry. Map of form <if of event reacted to, List of Reactors>
// reach Reactor is a list of 2-elements ( first is public id of reactor, second is comment)
Map< String, List<List<String>> > gReactions = {};

// bots ignored to reduce spam
List<String> gBots = [  "3b57518d02e6acfd5eb7198530b2e351e5a52278fb2499d14b66db2b5791c512",  // robosats orderbook
                        "887645fef0ce0c3c1218d2f5d8e6132a19304cdc57cd20281d082f38cfea0072",  // bestofhn
                        "f4161c88558700d23af18d8a6386eb7d7fed769048e1297811dcc34e86858fb2",  // bitcoin_bot
                        "105dfb7467b6286f573cae17146c55133d0dcc8d65e5239844214412218a6c36"   // zerohedge
                      ];

//const String gDefaultEventsFilename = "events_store_nostr.txt";
String       gEventsFilename        = ""; // is set in arguments, and if set, then file is read from and written to

const String gUsage = """$exename version $version
The nostr console client built using dart.

usage: $exename [OPTIONS] 

  OPTIONS

      --pubkey  <public key>    The hex public key of user whose events and feed are shown. Default is a hard-coded
                                well known private key. When given, posts/replies can't be sent. Same as -p
      --prikey  <private key>   The hex private key of user whose events and feed are shown. Also used to sign events 
                                sent. Default is a hard-coded well known private key. Same as -k
      --relay   <relay wss url> The relay url that is used as main relay. Default is $nostrRelayUnther . Same as -r
      --days    <N as num>      The latest number of days for which events are shown. Default is 1. Same as -d
      --request <REQ string>    This request is sent verbatim to the default relay. It can be used to recieve all events
                                from a relay. If not provided, then events for default or given user are shown. Same as -q
      --file    <filename>      Read from given file, if it is present, and at the end of the program execution, write
                                to it all the events (including the ones read, and any new received). Same as -f
      --translate               This flag, if present, will make the application translate some of the recent posts using
                                google translate. Save as -t
  UI Options                                
      --align  <left>           When "left" is given as option to this argument, then the text is aligned to left. By default
                                the posts or text is aligned to the center of the terminal. Same as -a 
      --width  <width as num>   This specifies how wide you want the text to be, in number of columns. Default is $gDefaultTextWidth. 
                                Cant be less than $gMinValidTextWidth. Same as -w
      --maxdepth <depth as num> The maximum depth to which the threads can be displayed. Minimum is $gMinimumDepthAllowed and
                                maximum allowed is $gMaximumDepthAllowed. Same as -m
      --help                    Print this usage message and exit. Same as -h
      
""";

const String helpAndAbout = 
'''
HOW TO USE
----------

* When entering a event you want to reply to, you need to enter only the first few letters of the event-id. Lets say the event is 

                                            +-------+
                                            |Author : vishalxl  id: 6c1  Time: 07:48 PM Aug 24, 2022
                                            |Message: example comment or post or reply

  The event id of this event is 6c1.

  When the UI asks for an event id, you can just enter 6c1, and press enter. Then the program will find the most recent event in its memory 
  with this prefix as its id, and send a reply/like to it. It is possible that some other event has the same 3 letter prefix, and is printed
  later than your own event, in which case a different event will get a reply/like. But the odds of that happening are very low if the event
  you are replying to is not too old. 

  To ensure that you reply to the exact right event id, invoke the program with --prefix N, where N is a large number. Then the program will
  display the first N letters of each event, and you can reply to a longer ID. N can be as large as 64. 

* 


EXAMPLES
--------

To get ALL the latest messages for last 3 days (on linux bash which allows backtick execution):

\$ nostr_console.exe  --request=`echo "[\\"REQ\\",\\"l\\",{\\"since\\":\$(date -d \\'-3 day\\' +%s)}]"`

To get the latest messages for user with private key K ( that is also used to sign posted/sent messages):

\$ nostr_console.exe  --prikey=K

To get the latest messages for user with private key K for last 4 days ( default is 1) from relay R:

\$ nostr_console.exe  --prikey=K --relay=R --days=4 

To write events to a file ( and later read from it too), for any given private key K:

\$ nostr_console.exe  --file=eventsFile.txt --prikey=K

PROGRAM ARGUMENTS
-----------------

Also seen by giving --help option when invoking the application.

$gUsage

KNOWN ISSUES
------------

* Does not get all the events, or in other words, does not properly get all the events from their own relays, and thus misses some events. 
* Does not work on Tor network

ABOUT
-----

Nostr console/terminal client. Built using Dart. 
Source Code and Binaries: https://github.com/vishalxl/nostr_console

''';
