#!/bin/bash

#mmdblookup --file ../conf/GeoLite2-City.mmdb --ip 111.202.148.49

IP=$1

mmdblookup --file ../conf/GeoLite2-City.mmdb --ip $IP

