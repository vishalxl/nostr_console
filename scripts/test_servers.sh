#!/bin/bash

configfile="./relay_list_all.txt"

if [[ $# -eq 1 ]] ; then
	if [ $1=="--help"  ]; then 
		echo 'Usage: ./test_servers.sh  <nostr relays filename(optional)>'
		echo 'nostr relays filename contains list of relays to test; its default value is relay_list_all.txt' 
		exit 1
	fi
	
	configfile=$1	
fi

source $configfile

limit=300
numHours=1

echo -e "Requesting all events in last $numHours hours with a limit of $limit by executing the following command for each:"
sinceSeconds=`date -d "-$numHours hour" +%s` ; 

N=2
inLastNDays=`date -d "$N days" +%s`

#echo "Events in last $N days"
#req="[\"REQ\",\"id_mention_#p_nostr.coinos.io\",{\"#p\":[\"82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2\"],\"limit\":20000,\"since\":$inLastNDays},{\"authors\":[\"82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2\"]}]"


req="[\"REQ\",\"l\",{\"since\":$sinceSeconds,\"limit\":$limit}]"; 

echo -e "Getting all events, with limit $limit, from servers in last $numHours hours by running command: "
    echo -e "    echo $req  | websocat <relay url> 2> /dev/null | wc -l \n\n"; 

for relay in ${nostr_relays[@]};
do
printf "Testing     %-40s: "  "$relay"
echo "$req" | websocat -B 300000 $relay 2> /dev/null | wc -l

done

