#!/bin/bash

source ./configfile.cfg

limit=200
numHours=6

echo -e "Requesting all evetns in last $numHours hours with a limit of $limit"
for server in ${nostr_servers[@]};
do
echo -e "\n\n------------Testing $server---------------------------\n"
sinceSeconds=`date -d "-$numHours hour" +%s` ; 
req="[\"REQ\",\"l\",{\"since\":$sinceSeconds,\"limit\":$limit}]"; 
echo  "echo $req  | websocat $server | wc " ; 
echo "$req" | websocat -B 300000 $server | wc

done
