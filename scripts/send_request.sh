#!/bin/bash

source ./configfile.cfg

# ./send_request.sh   '["REQ","name",{"ids":["b10180"]}]'

for relay in ${nostr_relays[@]};
do
>&2 echo -e  "\n\n------------Sending $1 to $relay---------------------------\n"
>&2 echo   "echo $1  | websocat $relay " ; 
echo "$1" | websocat -B 300000 $relay

done
