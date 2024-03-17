#!/bin/bash

configfile="./relay_list_all.txt"

if [[ $# -eq 0 ]] ; then
    echo 'Usage: ./send_request.sh <nostr request> <nostr relays filename(optional)>'
	echo 'nostr relays filename contains list of relays to use; its default value is relay_list_all.txt' 
    exit 1
fi

if [[ $# -eq 2 ]] ; then
	configfile=$2
fi


echo Going to use $configfile for list of relays to use.
source ./$configfile

# ./send_request.sh   '["REQ","name",{"ids":["b10180"]}]'
#  ./send_request.sh '["REQ","nnn",{"limit":2,"ids":["d8aa6787834de19f0cb61b2aeef94886b2284f36f768bf8b5cc7533988346997"]}]'

echo for loop
for relay in ${nostr_relays[@]};
do
>&2 echo -e  "\n\n------------Sending $1 to $relay---------------------------\n"
>&2 echo   "echo $1  | websocat $relay " ; 
echo "$1" | websocat -B 300000 $relay

done
