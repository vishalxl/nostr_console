# nostr_console
Nostr console client using Dart

# Use


Usage: 

```
usage: dart run bin/nostr_console.dart [OPTIONS] 

  OPTIONS

      --pubkey  <public key>    The hex public key of user whose events and feed are shown. Default is a hard-coded
                                well known private key. When given, posts/replies can't be sent. Same as -p
      --prikey  <private key>   The hex private key of user whose events and feed are shown. Also used to sign events 
                                sent. Default is a hard-coded well known private key. Same as -k
      --relay   <relay wss url> The relay url that is used as main relay. Default is wss://nostr-relay.untethr.me. Same as -r
      --days    <N as num>      The latest number of days for which events are shown. Default is 1. Same as -d
      --request <REQ string>    This request is sent verbatim to the default relay. It can be used to recieve all events
                                from a relay. If not provided, then events for default or given user are shown. Same as -q
  UI Options                                
      --align  <left>           When "left" is given as option to this argument, then the text is aligned to left. By default
                                the posts or text is aligned to the center of the terminal. Same as -a 
      --width  <width as num>   This specifies how wide you want the text to be, in number of columns. Default is 120. 
                                Cant be less than 60. Same as -w
      --maxdepth <depth as num> The maximum depth to which the threads can be displayed. Minimum is 2 and
                                maximum allowed is 12. Same as -m
      --help                    Print this usage message and exit. Same as -h
                               
```                                

To get ALL the latest messages for last 3 days (on linux which allows backtick execution): 

```
 dart run bin/nostr_console.dart  --request=`echo "[\"REQ\",\"l\",{\"since\":$(date -d '-3 day' +%s)}]"`
 ```
 
To get the latest messages for user with private key K ( that is also used to sign posted/sent messages): 
 
```
 dart run bin/nostr_console.dart  --prikey=K
```

To get the latest messages for user with private key K for last 4 days ( default is 1) from relay R: 
 
 ```
 dart run bin/nostr_console.dart  --prikey=K --relay=R --days=4 
 ```
 
 # Screenshots

![latest](https://pbs.twimg.com/media/FachGW3agAAele4?format=png&name=4096x4096) in mid Aug 2022.






 
