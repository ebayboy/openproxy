#!/bin/bash

ROOT_PATH="/usr/local/myresty/nginx"

mkdir -p /tmp/nginx/cache
mkdir -p /data/temp

$ROOT_PATH/sbin/nginx -c $ROOT_PATH/conf/nginx.conf -p $ROOT_PATH
