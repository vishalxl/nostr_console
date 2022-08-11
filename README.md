# nostr_console
Nostr console client using Dart

# Use

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



 
