#!/bin/bash

# writes hello to a group
#  echo '\n' ; for line in `cowsay hi` ;  do echo  -e "${line}\\\n" ; done

IFS=$'\n'
channel=25e5c
# { echo -e "3\n1\n${channel}\nHello, this is a random test.\nx\nx\nx" ; cat /dev/stdin; } | ./nostr_console_ubuntu_x64 --prikey=`openssl rand -hex 32` 


#  \n\n.____ \n< hi > \n ---- \n        \\\n           ^__^ \n           (oo)_______ \n           (__)       )/ \n               ||----w | \n               ||     || \n
message=""
message=$message'\n' ; for line in `cowsay hi` ;  do message=$message"${line} \n" ; done
echo $message
{ echo -e "3\n1\n${channel}\nHello, this is a random test.\nx\nx\nx" ; cat /dev/stdin; } | dart run ../bin/nostr_console.dart --prikey=`openssl rand -hex 32` 
