#!/bin/bash


echo "++++++++++++++++++++test default"
curl http://192.168.137.101/

echo "++++++++++++++++++++test lua"
curl http://192.168.137.101/lua

echo "++++++++++++++++++++test lua2"
curl http://192.168.137.101/lua2

echo "++++++++++++++++++++test redis"
curl http://192.168.137.101/redis_test


