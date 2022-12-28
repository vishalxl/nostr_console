#!/bin/bash

# tested on Linux/Ubuntu
# will go to the channel mentioned in this variable; change it to go to that channel
# arguments passed to this script are passed to the nostr_console 

channel=52ca
{ echo -e "3\n1\n${channel}" ; cat /dev/stdin; } | ./nostr_console_ubuntu_x64 $@

