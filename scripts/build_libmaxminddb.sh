#!/bin/bash


cd ../vendors/
tar xvf libmaxminddb.tar.gz
cd libmaxminddb/
./bootstrap
./configure

make

make install

cd ../../

