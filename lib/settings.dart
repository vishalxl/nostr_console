import 'dart:io';
import 'package:logging/logging.dart';

// name of executable
const String exename = "nostr_console";
const String version = "0.1.4-beta";

int gDebug = 0;
int gSpecificDebug = 0;

final log = Logger('ExampleLogger');

// for debugging
String gCheckEventId = "fg ee810ea73072af056cceaa6d051b4fcce60739247f7bcc752e72fa5defb64f09"; 

int gDefaultNumWaitSeconds = 3000; // is used in main()

//////////////////////////////////////////////////////////////////////////////////////////////////////////////// file related settings 
const String gDefaultEventsFilename = "all_nostr_events.txt";
String       gEventsFilename        = ""; // is set in arguments, and if set, then file is read from and written to
bool         gDontWriteOldEvents    = true;
const int gDontSaveBeforeDays       = 20; // dont save events older than this many days if gDontWriteOldEvents flag is true
const int gDeletePostsOlderThanDays = 20;
bool         gOverWriteFile         = false; // overwrite the file, and don't just append. Will write all events in memory. 

const int gDontAddToStoreBeforeDays = 60; // events older than this are not added to the Store of all events

const int gDaysToGetEventsFor       = 10; // when getting events, this is the since field (unless a fully formed request is given in command line)
const int gLimitPerSubscription     = 6000;

 // don't show notifications for events that are older than 5 days and come when program is running
 // applicable only for notifications and not for search results. Search results set a flag in EventData and don't use this variable
const int gDontHighlightEventsOlderThan = 4;

const int gMaxAuthorsInOneRequest = 100; // number of author requests to send in one request
const int gMaxPtagsToGet          = 150; // maximum number of p tags that are taken from the comments of feed ( the top most, most frequent)

// global counters of total events read or processed
int numFilePosts = 0, numUserPosts = 0, numFeedPosts = 0, numOtherPosts = 0;

//String defaultServerUrl = 'wss://relay.damus.io';
//const String nostrRelayUnther = 'wss://nostr-relay.untethr.me'; not working 
const String relayNostrInfo   = 'wss://relay.nostr.info';
String defaultServerUrl       = "wss://relay.damus.io";

List<String> gListRelayUrls1 = [ defaultServerUrl,
                                relayNostrInfo,
                                "wss://nostr.oxtr.dev",
                                "wss://nostr-verified.wellorder.net"
                              ];

List<String> gListRelayUrls2 = [
                              "wss://nostr-relay.wlvs.space",
                              "wss://nostr.ono.re"
                              ];

// well known disposable test private key
const String gDefaultPublicKey  = "e8caa2028a7090ffa85f1afee67451b309ba2f9dee655ec8f7e0a02c29388180";
String userPrivateKey = "";
String userPublicKey  = gDefaultPublicKey;

// default follows; taken from nostr.io/stats 
List<String> gDefaultFollows = [
                  "3efdaebb1d8923ebd99c9e7ace3b4194ab45512e2be79c1b7d68d9243e0d2681", //damus
                  "6b0d4c8d9dc59e110d380b0429a02891f1341a0fa2ba1b1cf83a3db4d47e3964"  // dergigi
                  "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245", // jb55
                  "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d", // fiatjaf
                  "2ef93f01cd2493e04235a6b87b10d3c4a74e2a7eb7c3caf168268f6af73314b5", // unclebobmarting 
                  "ed1d0e1f743a7d19aa2dfb0162df73bacdbc699f67cc55bb91a98c35f7deac69", // Melvincarvalho
                  "35d26e4690cbe1a898af61cc3515661eb5fa763b57bd0b42e45099c8b32fd50f", // scsibug
                  "9ec7a778167afb1d30c4833de9322da0c08ba71a69e1911d5578d3144bb56437", // balas
                  "46fcbe3065eaf1ae7811465924e48923363ff3f526bd6f73d7c184b16bd8ce4d", // Giszmo
                  "8c0da4862130283ff9e67d889df264177a508974e2feb96de139804ea66d6168", // monlovesmango
                  "c5072866b41d6b88ab2ffee16ad7cb648f940867371a7808aaa94cf7d01f4188", // randymcmillan
                  "2183e94758481d0f124fbd93c56ccaa45e7e545ceeb8d52848f98253f497b975", // Brill
                  "00000000827ffaa94bfea288c3dfce4422c794fbb96625b6b31e9049f729d700", // cameri
                  "dd81a8bacbab0b5c3007d1672fb8301383b4e9583d431835985057223eb298a5", // plantimals
                  "1c6b3be353041dd9e09bb568a4a92344e240b39ef5eb390f5e9e821273f0ae6f", // johnonchain
                  "52b4a076bcbbbdc3a1aefa3735816cf74993b1b8db202b01c883c58be7fad8bd", // semisol
                  "47bae3a008414e24b4d91c8c170f7fce777dedc6780a462d010761dca6482327", // slaninas
                  "c7eda660a6bc8270530e82b4a7712acdea2e31dc0a56f8dc955ac009efd97c86", // shawn 
                  "b2d670de53b27691c0c3400225b65c35a26d06093bcc41f48ffc71e0907f9d4a", // 0xtr
                  "f43c1f9bff677b8f27b602725ea0ad51af221344f69a6b352a74991a4479bac3", // manfromhighcastle
                  "80482e60178c2ce996da6d67577f56a2b2c47ccb1c84c81f2b7960637cb71b78", // Leo
                  "42a0825e980b9f97943d2501d99c3a3859d4e68cd6028c02afe58f96ba661a9d", // zerosequioso
                  "e8caa2028a7090ffa85f1afee67451b309ba2f9dee655ec8f7e0a02c29388180", // nostr_console test
                  "3235036bd0957dfb27ccda02d452d7c763be40c91a1ac082ba6983b25238388c"]; // vishalxl ]; 

 
// dummy account pubkey
const String gDummyAccountPubkey = "Non";

//////////////////////////////////////////////////////////////////////////////////////////////////////////////// UI and Color 
const int  gMinValidTextWidth   = 60; // minimum text width acceptable
const int  gDefaultTextWidth    = 96; // default text width
int        gTextWidth           = gDefaultTextWidth; // is changed by --width option
const int  gSpacesPerDepth      = 6;     // constant
int        gNumLeftMarginSpaces = 0;// this number is modified in main 
String     gAlignment           = "center";   // is modified in main if --align argument is given
const int  gapBetweenTopTrees   = 1;
const int gNameLengthInPost     = 12;

// after depth of maxDepthAllowed the thread is re-aligned to left by leftShiftThreadBy
const int  gMinimumDepthAllowed = 2;
const int  gMaximumDepthAllowed = 12;
const int  gDefaultMaxDepth     = 5;
int        maxDepthAllowed      = gDefaultMaxDepth;
const int  leftShiftThreadsBy   = 3;

int gMaxLenUnbrokenWord = 8; // lines are broken if space is at end of line for this number of places

int gMenuWidth          = 36;

// https://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html#8-colors
// Color related settings
const String defaultTextColor = "green";
const String greenColor       = "\x1B[32m"; // green
const String yellowColor       = "\x1B[33m"; // yellow
const String magentaColor     = "\x1B[35m"; // magenta
const String cyanColor        = "\x1b[36m"; // cyan
const String whiteColor       = "\x1b[37m"; // white
const String blackColor       = "\x1b[30m"; // black
const String redColor         = "\x1B[31m"; // red
const String blueColor        = "\x1b[34m"; // blue

Map<String, String> gColorMapForArguments = { "green": greenColor, 
                                  "cyan" : cyanColor, 
                                  "white": whiteColor, 
                                  "black": blackColor, 
                                  "red"  : redColor, 
                                  "blue" : blueColor};

const String brightBlackColor       = "\x1b[90m"; // bright black
const String brightRedColor         = "\x1B[91m"; // bright red
const String brightGreenColor       = "\x1B[92m"; // bright green
const String brightYellowColor      = "\x1B[93m"; // bright yellow
const String brightBlueColor        = "\x1B[94m"; // bright blue
const String brightCyanColor        = "\x1B[96m"; // bright cyan
const String brightMagentaColor     = "\x1B[95m"; // bright magenta
const String brightWhiteColor       = "\x1b[97m"; // white

// 33 yellow, 31 red, 34 blue, 35 magenta. Add 60 for bright versions. 
String gCommentColor = greenColor;
String gNotificationColor = cyanColor; // cyan
String gWarningColor = redColor; // red
const String gColorEndMarker = "\x1B[0m";

// blue is too bright
/*
e & f are red
c & d are pink
a & b are orange
8 & 9 are yellow
6 & 7 are green
4 & 5 are light blue
2 & 3 are blue
0 & 1 are purple


List<String> nameColorPalette = [brightGreenColor, brightCyanColor, brightYellowColor, brightMagentaColor, 
                                 brightBlueColor, brightRedColor, brightBlackColor, brightWhiteColor,
                                 yellowColor,        magentaColor,             redColor ];

List<String> nameColorPalette = [brightMagentaColor, brightBlueColor, brightCyanColor, brightGreenColor, 
                                brightYellowColor,   brightRedColor,  yellowColor,   redColor        ];


*/

Map<String, String> pubkeyColor = { '0': magentaColor, '1': brightMagentaColor,
                                    '2': blueColor, '3': brightBlueColor,  
                                    '4': cyanColor, '5': brightCyanColor, 
                                    '6': brightGreenColor, '7': brightGreenColor, 
                                    '8': brightYellowColor,'9': brightYellowColor,  
                                    'a': brightRedColor,  'b':  brightRedColor, 
                                    'c': yellowColor,     'd':  yellowColor, 
                                    'e': redColor,        'f':  redColor 
                                   };


String getNameColor( String pubkey) {
  if( pubkey.length == 0)
    return brightMagentaColor;

  String firstChar = pubkey.substring(0, 1).toLowerCase();
  return pubkeyColor[firstChar]??brightMagentaColor;
}


// By default the threads that were started in last one day are shown
// this can be changed with 'days' command line argument
const int gDefaultNumLastDays = 1;
int gNumLastDays     = gDefaultNumLastDays; 

const bool gWhetherToSendClientTag = true;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////// bots related settings 
// bots ignored to reduce spam
List<String> gBots = [  "3b57518d02e6acfd5eb7198530b2e351e5a52278fb2499d14b66db2b5791c512",  // robosats orderbook
                        "887645fef0ce0c3c1218d2f5d8e6132a19304cdc57cd20281d082f38cfea0072",  // bestofhn
                        "f4161c88558700d23af18d8a6386eb7d7fed769048e1297811dcc34e86858fb2",  // bitcoin_bot
                        "105dfb7467b6286f573cae17146c55133d0dcc8d65e5239844214412218a6c36",  // zerohedge
                        "e89538241bf737327f80a9e31bb5771ccbe8a4508c04f1d1c0ce7336706f1bee",  // Bitcoin news
                        "6a9eb714c2889aa32e449cfbb7854bc9780feed4ff3d887e03910dcb22aa560a",   // "bible bot"

                        "3104f98515b3aa147d55d9c2951e0f953b829d8724381d8f0d824125d7727634",   // 42 spammer
                        "6bc83d6a806b7a2c3e1fa07d3352402f7b6886b81a975090d6d89bb631c3dad9"
                      ];

//////////////////////////////////////////////////////////////////////////////////////////////////////////////// difficulty related settings
const int gMaxDifficultyAllowed = 24;                      
int gDifficulty = 0;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////// channel related settings
const int gNumChannelMessagesToShow = 18;
const int gMaxChannelPagesDisplayed = 50;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////// User interface messages
String gDeletedEventMessage = "This post was deleted by its original writer";

const String gUsage = """$exename version $version
The nostr console client built using dart.

usage: $exename [OPTIONS] 

  OPTIONS

      -p, --pubkey  <public key>    The hex public key of user whose events and feed are shown. Default is a hard-coded
                                    well known private key. When given, posts/replies can't be sent.
      -k, --prikey  <private key>   The hex private key of user whose events and feed are shown. Also used to sign events 
                                    sent. Default is a hard-coded well known private key.
      -r, --relay   <relay wss url> The relay url that is used as main relay. Default is wss://relay.damus.io.
      -d, --days    <N as num>      The latest number of days for which events are shown. Default is $gDefaultNumLastDays.
      -q, --request <REQ string>    This request is sent verbatim to the default relay. It can be used to recieve all events
                                    from a relay. If not provided, then events for default or given user are shown.
      -f, --file    <filename>      Read from given file, if it is present, and at the end of the program execution, write
                                    to it all the events (including the ones read, and any new received). Even if not given, 
                                    the default is to read from and write to $gDefaultEventsFilename . Can be turned off by 
                                    the --disable-file flag 
      -s, --disable-file            When turned on, even the default filename is not read from.
      -t, --translate               Translate some of the recent posts using Google translate site ( and not api). Google 
                                    is accessed for any translation request only if this flag is present, and not otherwise.
      -h, --help                    Print help/usage message and exit. 
      -v, --version                 Print version and exit.

  UI Options                                
      -a, --align  <left>           When "left" is given as option to this argument, then the text is aligned to left. By default
                                    the posts or text is aligned to the center of the terminal.
      -w, --width  <width as num>   This specifies how wide you want the text to be, in number of columns. Default is $gDefaultTextWidth. 
                                    Cant be less than $gMinValidTextWidth.
      -m, --maxdepth <depth as num> The maximum depth to which the threads can be displayed. Minimum is $gMinimumDepthAllowed and
                                    maximum allowed is $gMaximumDepthAllowed.
      -c, --color  <color>          Color option can be green, cyan, white, black, red and blue.

  Advanced
      -y, --difficulty <number>     The difficulty number in bits, only for kind 1 messages. Tne next larger number divisible by 4 is 
                                    taken as difficulty. Can't be more than 24 bits, because otherwise it typically takes too much 
                                    time. Minimum and default is 0, which means no difficulty.
      -e, --overwrite               Will over write the file with all the events that were read from file, and all newly received. Is
                                    useful when the file has to be cleared of old unused events. A backup should be made just in case
                                    of original file before invoking.
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
  

EXAMPLES
--------

To get ALL the latest messages for last 3 days (on linux bash which allows backtick execution):

\$ nostr_console.exe  --request=`echo "[\\"REQ\\",\\"l\\",{\\"since\\":\$(date -d \\'-3 day\\' +%s)}]"`

To get the latest messages for user with private key K ( that is also used to sign posted/sent messages):

\$ nostr_console.exe  --prikey=K

To get the latest messages for user with private key K for last 4 days ( default is 1) from relay R:

\$ nostr_console.exe  --prikey=K --days=4 

To write events to a file ( and later read from it too), for any given private key K:

\$ nostr_console.exe  --file=eventsFile.txt --prikey=K

PROGRAM ARGUMENTS
-----------------

Also seen by giving --help option when invoking the application.

$gUsage

KNOWN ISSUES
------------

* Does not work on Tor network

ABOUT
-----

Nostr console/terminal client. Built using Dart. 
Source Code and Binaries: https://github.com/vishalxl/nostr_console

''';

void printIntro(String msg) {

String intro = 
"""

           ▀█▄   ▀█▀                  ▄           
            █▀█   █    ▄▄▄    ▄▄▄▄  ▄██▄  ▄▄▄ ▄▄  
            █ ▀█▄ █  ▄█  ▀█▄ ██▄ ▀   ██    ██▀ ▀▀ 
            █   ███  ██   ██ ▄ ▀█▄▄  ██    ██     
           ▄█▄   ▀█▄  ▀█▄▄█▀ █▀▄▄█▀  ▀█▄▀ ▄██▄    
 
  ██████╗ ██████╗ ███╗   ██╗███████╗ ██████╗ ██╗     ███████╗
 ██╔════╝██╔═══██╗████╗  ██║██╔════╝██╔═══██╗██║     ██╔════╝
 ██║     ██║   ██║██╔██╗ ██║███████╗██║   ██║██║     █████╗  
 ██║     ██║   ██║██║╚██╗██║╚════██║██║   ██║██║     ██╔══╝  
 ╚██████╗╚██████╔╝██║ ╚████║███████║╚██████╔╝███████╗███████╗
  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝╚══════╝


""";           

List<String> lines = intro.split("\n");

var terminalColumns = gDefaultTextWidth;

if( stdout.hasTerminal )
  terminalColumns = stdout.terminalColumns;

lines.forEach((line) {print(line.length > terminalColumns ? line.substring(0, terminalColumns) : line );});

}
