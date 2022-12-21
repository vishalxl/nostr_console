# nostr_console
Nostr console client using Dart

# todo

* support bech32 keys
* increase author id to 5 and event id shown to 6 from 3 and 4 respectively
* add new relays  ( zbd)
* menu should honour --width, its extending way beyond
* fix issue where need to go back into main menu to update the feed
* prikey from file, create it too --genkey 
* initial creation of private/pub key 
* fix --help that's dated
* show lightning invoice as qr code 
* notifications should show mentions too ( it does not yet) 
* notifications , option 3, is shown only for one entry in whole thread 
* hashtag regexp should have underscore 
* add more default users. improve who is fetched. 
* after going to a dm room, screen doesn't clear 
* when seeing a profile, if they have liked something, then likes after their name are shown white
* kind 7 tags are messed up. for example for reaction: 066cdb716e250069c4078565c9d9046af483c43bbd8497aad9c60d41ec462034 and 137289198ff1c57a14711d87b059e5fc5f9b11b257672503595ac31bad450a22
* allow special character input, and 256 limit [info](https://www.reddit.com/r/dartlang/comments/xcdsyx/i_am_seeing_that_stdinreadlinesync_returns_only/)


# other longer term todo
* parallel connections to relays in different isolate 
* build appimage for linux use


# Running Nostr Console using Docker

```
docker build  -t nostr_console .
```

Then run using
```
docker run -it nostr_console start
```


# Running Remotely Using Docker

Use Nostr Terminal + Nostr Console to run Nostr Console remotely from a  browser. 

Build using 
```
docker build  -f Dockerfile.remote -t nostr_console_remote .
```

Then run using
```
docker run -it nostr_console_remote start
```

Do keep security/privacy factors in mind. The link is basically an online backdoor into the local terminal. Related info [here](https://github.com/vishalxl/nostr_console/discussions/18)


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
      -r, --relay   <relay wss url> The comma separated relay urls that are used as main relay. Default is wss://nostr-relay.untethr.me.
      -d, --days    <N as num>      The latest number of days for which events are shown. Default is 1.
      -q, --request <REQ string>    This request is sent verbatim to the default relay. It can be used to receive all events
                                    from a relay. If not provided, then events for default or given user are shown.
      -f, --file    <filename>      Read from given file, if it is present, and at the end of the program execution, write
                                    to it all the events (including the ones read, and any new received).
      -s, --disable-file            When turned on, even the default file is not read from.
      -t, --translate               Translate some of the recent posts using Google translate site ( and not api). Google 
                                    is accessed for any translation request only if this flag is present, and not otherwise.
      -l, --location                The given value is added as a 'location' tag with every kind 1 post made
      -h, --help                    Print help/usage message and exit. 
      -v, --version                 Print version and exit.

  UI Options                                
      -a, --align  <left>           When "left" is given as option to this argument, then the text is aligned to left. By default
                                    the posts or text is aligned to the center of the terminal. 
      -w, --width  <width as num>   This specifies how wide you want the text to be, in number of columns. Default is 100. 
                                    Can't be less than 60.
      -m, --maxdepth <depth as num> The maximum depth to which the threads can be displayed. Minimum is 2 and
                                    maximum allowed is 12. 
      -c, --color  <color>          Color option can be green, cyan, white, black, red and blue.

  Advanced
      -y, --difficulty <number>     The difficulty number in bits, only for kind 1 messages. The next larger number divisible by 4 is 
                                    taken as difficulty. Can't be more than 24 bits, because otherwise it typically takes too much 
                                    time. Minimum and default is 0, which means no difficulty.
      -e, --overwrite               Will over write the file with all the events that were read from file, and all newly received. Is
                                    useful when the file has to be cleared of old unused events. A backup should be made just in case
                                    of original file before invoking.

```                                

# Command line examples

To 'login' as a user with private key K: 
 
```
nostr_console.exe  --prikey=K
```


To get ALL the latest messages on relays for last 3 days (on bash shell which allows backtick execution), for user with private key K: 

```
nostr_console.exe  --prikey=K --request=`echo "[\"REQ\",\"l\",{\"since\":$(date -d '-3 day' +%s)}]"`
```
 
# Configuring Proxy
When you are in an network which blocks outgoing HTTPS (e.g. company firewall), but there is a proxy you can set environment variable before running nostr_console.
Examples below use authentication. Drop username:password if not required.

## Linux
```
$ export HTTP_PROXY=http://username:password@proxy.example.com:1234
$ export HTTPS_PROXY=http://username:password@proxy.example.com:5678
```
To make permanent add to your shell profile, e.g. ~/.bashrc or to /etc/profile.d/

## Windows
```
C:\setx HTTP_PROXY=http://username:password@proxy.example.com:1234
C:\setx HTTPS_PROXY=http://username:password@proxy.example.com:5678
```
Using [setx](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setx) to set an environment variable changes the value used in both the current command prompt session and all command prompt sessions that you create after running the command. It does not affect other command shells that are already running at the time you run the command.

Use [set](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/set_1) to set an environment variable changes the value used until the end of the current command prompt session, or until you set the variable to a different value.


# Screenshots

<img width="1280" alt="2022-12-02 (5)" src="https://user-images.githubusercontent.com/64505169/205257958-8b9cdb32-2139-48dc-8394-dc1952ef825d.png">
Showing Social network thread with re-shifting to left where threads are re-alignment to left for easier reading. 

<img width="1280" alt="2022-12-02 (6)" src="https://user-images.githubusercontent.com/64505169/205258177-3d236aaa-2745-4f99-8f04-f75a1442cee6.png">

Public channels overview with menu

<img width="1280" alt="2022-12-02 (7)" src="https://user-images.githubusercontent.com/64505169/205258403-ca81a17f-374b-4858-aa08-86e1e2f29b17.png">

How public channels look like as of mid late 2022, with --translate flag automatically translating into English.


# Contact

[Nostr Telegram Channel](https://t.me/nostr_protocol)

[Nostr Console Telegram channel](https://t.me/+YswV5fvfvPwyNmI1)

Nostr Pulic Channel 52cab2e3e504ad6447d284b85b5cc601ca0613b151641e77facfec851c2ca816



