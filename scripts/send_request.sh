#!/bin/bash

source ./configfile.cfg

for server in ${nostr_servers[@]};
do
>&2 echo -e  "\n\n------------Sending $1 to $server---------------------------\n"
>&2 echo   "echo $1  | websocat $server " ; 
echo "$1" | websocat -B 300000 $server

done
