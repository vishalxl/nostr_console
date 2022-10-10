# nostr_console
Nostr console client using Dart


# todo

* initial creation of private/pub key ( and loading happens in background)
* mention all user names in a reply post, rather than just the replied-to user
* clear screen between menus
* new menu system with three top apps: social network, public channels, and DM's
* allow special character input, and 256 limit [info](https://www.reddit.com/r/dartlang/comments/xcdsyx/i_am_seeing_that_stdinreadlinesync_returns_only/)

# other todo
* build appimage for linux use
* create new public room from kind 1 messages ( by reacting to a kind 1 message with special reaction with comment which would be new room's name)


# Use

Easiest way to run nostr_console: Go to releases and get an executable for your platform.

Otherwise do following:
1. Install [Flutter](https://docs.flutter.dev/get-started/install) SDK, or [Dart](https://dart.dev/get-dart) SDK
2. git clone this repository
3. From the project folder, run command ```dart pub get``` which gets all the dependencies
4. Run command ```dart run bin/nostr_console.dart```, which will run it with default settings. 
5. Further you can create an executable for your platform by  ```dart compile exe bin/nostr_console.dart``` which will create an executable for your platform. You can invoke that exe with required parameters. On Windows, you can create a shortcut to it with your desired command line arguments mentioned in it.

Usage: 

```
usage: dart run bin/nostr_console.dart [OPTIONS] 

  OPTIONS

      -p, --pubkey  <public key>    The hex public key of user whose events and feed are shown. Default is a hard-coded
                                    public key derived from a well known private key. When given, posts/replies can't be sent. 
      -k, --prikey  <private key>   The hex private key of user whose events and feed are shown. Also used to sign events 
                                    sent. Default is same-as-above hard-coded well known private key. 
      -r, --relay   <relay wss url> The relay url that is used as main relay. Default is wss://nostr-relay.untethr.me.
      -d, --days    <N as num>      The latest number of days for which events are shown. Default is 1.
      -q, --request <REQ string>    This request is sent verbatim to the default relay. It can be used to recieve all events
                                    from a relay. If not provided, then events for default or given user are shown.
      -f, --file    <filename>      Read from given file, if it is present, and at the end of the program execution, write
                                    to it all the events (including the ones read, and any new received).
      -s, --disable-file            When turned on, even the default file is not read from.
      -t, --translate               Translate some of the recent posts using Google translate site ( and not api). Google 
                                    is accessed for any translation request only if this flag is present, and not otherwise.

  UI Options                                
      -a, --align  <left>           When "left" is given as option to this argument, then the text is aligned to left. By default
                                    the posts or text is aligned to the center of the terminal. 
      -w, --width  <width as num>   This specifies how wide you want the text to be, in number of columns. Default is 100. 
                                    Cant be less than 60.
      -m, --maxdepth <depth as num> The maximum depth to which the threads can be displayed. Minimum is 2 and
                                    maximum allowed is 12. 
      -c, --color  <color>          Color option can be green, cyan, white, black, red and blue.
      -h, --help                    Print this usage message and exit.

  Advanced
      -y, --difficulty <number>     The difficulty number in bits, only for kind 1 messages. Tne next larger number divisible by 4 is 
                                    taken as difficulty. Can't be more than 24 bits, because otherwise it typically takes too much 
                                    time. Minimum and default is 0, which means no difficulty.
      -v, --overwrite               Will over write the file with all the events that were read from file, and all newly received. Is
                                    useful when the file has to be cleared of old unused events. A backup should be made just in case
                                    of original file before invoking.

```                                

To get ALL the latest messages for last 3 days (on linux which allows backtick execution): 

```
nostr_console.exe  --request=`echo "[\"REQ\",\"l\",{\"since\":$(date -d '-3 day' +%s)}]"`
```
 
To get the latest messages for user with private key K ( that is also used to sign posted/sent messages): 
 
```
nostr_console.exe  --prikey=K
```

To get the latest messages for user with private key K for last 4 days ( default is 1) from relay R: 
 
```
nostr_console.exe  --prikey=K --relay=R --days=4 
```

 To write events to a file ( and later read from it too), for any given private key K:

```
nostr_console.exe  --file=eventsFile.txt --prikey=K
```

 
 # Screenshots

![Social network](https://pbs.twimg.com/media/FcdrdCVX0AE77RC?format=png&name=4096x4096) late mid sept 2022.

![Showing Tree with re-shifting to left](https://pbs.twimg.com/media/FcdsoTeX0AApZ53?format=png&name=4096x4096); threads are re-alignment to left for easier reading.

![Public channels overview with menu](https://pbs.twimg.com/media/FcdsFm9XoAAk3m3?format=png&name=4096x4096)

# Contact

[Nostr Telegram Channel](https://t.me/nostr_protocol) or at Nostr Pulic Channel 52cab2e3e504ad6447d284b85b5cc601ca0613b151641e77facfec851c2ca816


