# nostr_console
Nostr console client using Dart

# Use


Usage: 

```
  OPTIONS

      --prikey  <private key>   The hex private key of user whose events and feed are shown. Also used to sign events
                                sent. Default is a hard-coded well known private key. -p is same.
      --relay   <relay wss url> The relay url that is used as main relay. Default is wss://nostr-relay.untethr.me . -r is same.
      --days    <N>             The latest number of days for which events are shown. Default is 1. -d is same.
      --request <REQ string>    This request is sent verbatim to the default relay. It can be used to recieve all events
                                from a relay. If not provided, then events for default or given user are shown. -q is same.
```                                

To get ALL the latest messages for last 3 days: 

```
 dart run bin/nostr_console.dart  --request=`echo "[\"REQ\",\"l\",{\"since\":$(date -d '-3 day' +%s)}]"`
 ```
 
To get the latest messages for user with public key K: 
 
```
 dart run bin/nostr_console.dart  --user=K
```

To get the latest messages for user with public key K for last 4 days ( default is 3) from relay R: 
 
 ```
 dart run bin/nostr_console.dart  --user=K --relay=R --days=4 
 ```





 
