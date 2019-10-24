#!/bin/bash

rm lib/* -rf

#lua-resty-cookie  
cp lua-resty-cookie/lib/resty/ lib/ -R

#lua-resty-http  
cp lua-resty-http/lib/resty/ lib/ -R

#build myresty-lua-module
cp myresty-lua-module/myresty/ lib/ -R

cp lib/* /usr/local/myresty/lualib/ -R
