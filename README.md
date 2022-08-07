# nostr_console
Nostr console client using Dart

# Use

To get the latest messages for last 3 days: 

```
 dart run bin/nostr_console.dart  --request=`echo "[\"REQ\",\"l\",{\"since\":$(date -d '-3 day' +%s)}]"`
 ```
