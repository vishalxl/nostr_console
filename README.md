# nostr_console
Nostr console client using Dart

This is an experimental or pre-alpha software made to show or know what a Nostr network client would look like. It works 90% of the time everytime; less when relays are not working perfectly. 


# todo

* [ ] allow faster startup with an argument or config
* [ ] menu should honour --width, its extending way beyond
* [ ] after going to a dm room, screen doesn't clear 
* [ ] in url expansions, the likes string is shown in same line which is wrong
* [ ] fix: users who don't have kind 0 or kind 3 are not searchable in menu 8 and 9 in Social network. 
* [ ] kind 7 tags are messed up. for example for reaction: 066cdb716e250069c4078565c9d9046af483c43bbd8497aad9c60d41ec462034 and 137289198ff1c57a14711d87b059e5fc5f9b11b257672503595ac31bad450a22
* [ ] fix count of events shown per relay in app stats
* [-] read prikey from file; create it too using new feature --genkey 
* [x] allow special character input, and 256 limit [info](https://www.reddit.com/r/dartlang/comments/xcdsyx/i_am_seeing_that_stdinreadlinesync_returns_only/)
* [x] fix --help that's dated
* [x] support bech32 keys
* [x] (showing tick for now) A F for friend or follow should be shown after each name that's a follow of the logged in user. F1 if the name is follow of a follow, and F2 if next level. 
* [x] due to extra color related bytes, reactions in highlighted threads are shifted a lot to left. fix that. 
* [x] increase author id to 5 and event id shown to 6 from 3 and 4 respectively
* [x] add new relays  ( zbd, coinos, radixrat)
* [x] fix issue where need to go back into main menu to update the feed
* [x] show lightning invoice as qr code 
* [x] in mention expansion, if p tag is not found in user store, then its left as #[n], whereas it should be replaced by the pubkey 
* [x] notifications should show mentions too ( it does not yet)
* [x] notifications , option 3, is shown only for one entry in whole thread 
* [x] hashtag regexp should have underscore  (seems to be working fine)
* [x] add more default users. improve who is fetched. 
* [x] when seeing a profile, if they have liked something, then likes after their name are shown white


# other longer term todo
* [ ] parallel connections to relays in different isolate 
* [ ] build appimage for linux use
* [ ] have spam rules file, which user can add and block spam


# Running Nostr Console using Docker

First check out or unzip the code to a directory, `cd` to that directory, and from there type the following commands:
(make sure Docker desktop is running in the background) 

```
docker build  -t nostr_console .
```

Then run using
```
docker run -it nostr_console start
```

## Prebuilt Docker Images

Prebuilt docker image from the main branch of this repository can be found [here](https://github.com/vishalxl/nostr_console/pkgs/container/nostr_console). 

`docker pull ghcr.io/vishalxl/nostr_console:main`

and then 

`docker run -it ghcr.io/vishalxl/nostr_console:main`



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

      -k, --prikey  <private key>   The nsec or hex private key of user you want to 'log in' as.
      -p, --pubkey  <public key>    The npub or hex public key of user whose events and feed are shown. When given,
                                    posts/replies can't be sent because for that a private key is needed.
      -r, --relay   <relay urls>    The comma separated relay urls that are used as relays. If given, these are used
                                    rather than the default relays.
      -f, --file    <filename>      Read from given file, if it is present, and at the end of the program execution, write
                                    to it all the events (including the ones read, and any new received). Even if not given,
                                    the default is to read from and write to all_nostr_events.txt . Can be turned off by
                                    the --disable-file flag
      -d, --days    <N as num>      The latest number of days for which events are shown. Default is 1.
      --request <REQ string>        This request is sent verbatim to the default relay. It can be used to recieve all events
                                    from a relay. If not provided, then events for default or given user are shown.
      -s, --disable-file            When turned on, even the default filename is not read from.
      -t, --translate               Translate some of the recent posts using Google translate site ( and not api). Google
                                    is accessed for any translation request only if this flag is present, and not otherwise.
      -l, --lnqr                    Flag, if set any LN invoices starting with LNBC will be printed as a QR code. Will set
                                    width to 140, which can be reset if needed with the --width argument. Wider
                                    space is needed for some qr codes.
      -g, --location <location>     The given value is added as a 'location' tag with every kind 1 post made. g in shortcut
                                    standing for geographic location.
      -h, --help                    Print help/usage message and exit.
      -v, --version                 Print version and exit.

  UI Options
      -a, --align  <left>           When "left" is given as option to this argument, then the text is aligned to left. By
                                    default the posts or text is aligned to the center of the terminal.
      -w, --width  <width as num>   This specifies how wide you want the text to be, in number of columns. Default is 96.
                                    Cant be less than 60.
      -m, --maxdepth <depth as num> The maximum depth to which the threads can be displayed. Minimum is 2 and
                                    maximum allowed is 12.
      -c, --color  <color>          Color option can be green, cyan, white, black, red and blue.

  Advanced
      -y, --difficulty <number>     The difficulty number in bits, only for kind 1 messages. Tne next larger number divisible
                                    by 4 is taken as difficulty. Can't be more than 32 bits, because otherwise it typically
                                    takes too much time. Minimum and default is 0, which means no difficulty.
      -e, --overwrite               Will over write the file with all the events that were read from file, and all newly
                                    received. Is useful when the file has to be cleared of old unused events. A backup should
                                    be made just in case of original file before invoking.

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
 
To get all encrypted messages:
```
./nostr_console_elf64 --prikey=K --request='["REQ","cn",{"limit":20000,"kinds":[104,140,141,142],"since":1663417739}]' # run on linux/bash
```

To run unit tests using Dart, in main/top level directory, run:

```
dart run test  -r expanded
```

# Troubleshooting

In case program is not sending events:

1. Make sure you are running the latest version. ( versions from 0.2.6 to 0.2.9 were very unstable)
2. Delete or backup the events file. Specially if its is more than 50 MB or has more than 50k events. 
3. Right after starting, go to social network menu, and press 1 or such menu a couple of times (to print events) to allow some background processing, so that events can be processed. Once all "notifications" or new events have come in, then try sending your event(s)

In case program is not fetching events:
1. Give it other or more relays' using --relay argument. 
2. If event file is more than 50 MB, delete/backup it and start again. 

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

## Tor proxy

TOR can be used as a HTTP proxy with HTTPTunnelPort instead of just SOCKS5.

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



