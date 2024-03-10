#!/bin/bash

source ./configfile.cfg


# ./send_request.sh   '["REQ","name",{"ids":["b10180"]}]'
#  ./send_request.sh '["REQ","nnn",{"limit":2,"ids":["d8aa6787834de19f0cb61b2aeef94886b2284f36f768bf8b5cc7533988346997"]}]'

for relay in ${nostr_relays[@]};
do
>&2 echo -e  "\n\n------------Sending $1 to $relay---------------------------\n"
>&2 echo   "echo $1  | websocat $relay " ; 
echo "$1" | websocat -B 300000 $relay

done
