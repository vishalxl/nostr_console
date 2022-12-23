#!/bin/bash

source ./configfile.cfg

limit=100000
numHours=1

echo -e "Requesting all events in last $numHours hours with a limit of $limit by executing the following command for each:"
sinceSeconds=`date -d "-$numHours hour" +%s` ; 
req="[\"REQ\",\"l\",{\"since\":$sinceSeconds,\"limit\":$limit}]"; 
echo  "echo $req  | websocat $server | wc " ; 

for server in ${nostr_servers[@]};
do
echo -e "\n\n------------Testing $server---------------------------\n"
echo "$req" | websocat -B 300000 $server | wc

done
