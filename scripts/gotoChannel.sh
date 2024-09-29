#!/bin/bash

# * tested on Linux/Ubuntu
# * will go to the channel mentioned in this variable; change it to go to that channel
# * arguments passed to this script are passed to the nostr_console 


#channel=52ca nostr console channel

channel=25e5c # nostr channel 
{ echo -e "3\n1\n${channel}" ; cat /dev/stdin; } | dart run ../bin/nostr_console.dart $@

