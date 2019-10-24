#!/bin/bash

USER=$1
PASSWD=$2
printf "$USER:$(openssl passwd -1 $PASSWD)\n" >> .htpasswd
