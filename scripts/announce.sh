#!/bin/bash

# writes hello to a group

channel=test99
{ echo -e "3\n1\n${channel}\nHello, this is a random test.\nx\nx\nx" ; cat /dev/stdin; } | ./nostr_console_ubuntu_x64 --prikey=`openssl rand -hex 32` 
