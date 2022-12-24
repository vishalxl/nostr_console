#!/bin/bash

source ./configfile.cfg

limit=100000
numHours=1

echo -e "Requesting all events in last $numHours hours with a limit of $limit by executing the following command for each:"
sinceSeconds=`date -d "-$numHours hour" +%s` ; 

#3235
#req="[\"REQ\",\"id_mention_#p_nostr.coinos.io\",{\"#p\":[\"3235036bd0957dfb27ccda02d452d7c763be40c91a1ac082ba6983b25238388c\"],\"limit\":20000,\"since\":1654569836},{\"authors\":[\"3235036bd0957dfb27ccda02d452d7c763be40c91a1ac082ba6983b25238388c\"]}]"
#jack
N=2
inLastNDays=`date -d "$N days" +%s`
#echo "Events in last $N days"
#req="[\"REQ\",\"id_mention_#p_nostr.coinos.io\",{\"#p\":[\"82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2\"],\"limit\":20000,\"since\":$inLastNDays},{\"authors\":[\"82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2\"]}]"
#req="[\"REQ\",\"id_mention_#e6_nostr.coinos.io\",{\"ids\":[\"df802463b9342b3c12b4f5ab674344dccb9dc152d3e4d7519d0cbd1cd92ce61f\",\"25e5c82273a271cb1a840d0060391a0bf4965cafeb029d5ab55350b418953fbb\",\"52cab2e3e504ad6447d284b85b5cc601ca0613b151641e77facfec851c2ca816\"],\"since\":1654570451}]"
#req="[\"REQ\",\"id_mention_tag_nostr.coinos.io\",{\"#e\":[\"df802463b9342b3c12b4f5ab674344dccb9dc152d3e4d7519d0cbd1cd92ce61f\",\"25e5c82273a271cb1a840d0060391a0bf4965cafeb029d5ab55350b418953fbb\",\"52cab2e3e504ad6447d284b85b5cc601ca0613b151641e77facfec851c2ca816\"],\"since\":1654570451},{\"ids\":[\"df802463b9342b3c12b4f5ab674344dccb9dc152d3e4d7519d0cbd1cd92ce61f\",\"25e5c82273a271cb1a840d0060391a0bf4965cafeb029d5ab55350b418953fbb\",\"52cab2e3e504ad6447d284b85b5cc601ca0613b151641e77facfec851c2ca816\"]}]"

req="[\"REQ\",\"l\",{\"since\":$sinceSeconds,\"limit\":$limit}]"; 

echo -e "Getting all events from servers in last $numHours hours by running command: "
    echo -e "    echo $req  | websocat <relay url> 2> /dev/null | wc -l \n\n"; 

for server in ${nostr_servers[@]};
do
printf "Testing     %-40s: "  "$server"
echo "$req" | websocat -B 300000 $server 2> /dev/null | wc -l

done

