#!/bin/bash

INSTALL_PATH=/usr/local/myresty
OPENSSL_PATH=./vendors/openssl-1.0.2r

rm -rf vendors/openssl-1.0.2r

tar -xf vendors/openssl-1.0.2r.tar.gz -C vendors/

./configure \
    --prefix=/usr/local/myresty \
    --with-http_realip_module \
    --with-http_sub_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    --with-pcre \
    --with-threads  \
    --with-luajit   \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_stub_status_module  \
    --with-http_image_filter_module  \
    --with-openssl=./vendors/openssl-1.0.2r \
    --add-module=./3Party/ngx_http_geoip2_module    \
    --add-module=./3Party/nginx-auth-ldap   \
    --add-module=./3Party/nginx-sticky-module-ng    

gmake && gmake install

#install my lua_modules
cd 3Party/lua_modules 
sh ./build_lua_modules.sh  
cp lib/* /usr/local/myresty/lualib/ -R
cd -

#tar 
