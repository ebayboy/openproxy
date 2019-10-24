#!/bin/bash

#./geoip2_find_county.sh 133.1.16.172

IP=$1

mmdblookup --file ../conf/GeoLite2-Country.mmdb --ip $IP

