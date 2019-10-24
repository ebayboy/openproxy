#!/bin/bash

BUILD_PATH=./build/
OPENRESTY_VER=openresty-1.15.8.2
BUILD_ROOT=$BUILD_PATH/openresty
INSTALL_PATH=/usr/local/myresty

rm -rf $BUILD_PATH && mkdir $BUILD_PATH

tar -xvf vendors/$OPENRESTY_VER.tar.gz -C $BUILD_PATH  1>/dev/null || exit 1;

mv $BUILD_PATH/$OPENRESTY_VER/ $BUILD_ROOT 1>/dev/null || exit 1;

#copy code
cp -afR 3Party/ $BUILD_ROOT

cd $BUILD_ROOT

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
    --with-http_image_filter_module  

gmake && gmake install

#install my lua_modules
#cd ./3Party/lua_modules 
#sh ./build_lua_modules.sh  
#cp lib/* /usr/local/myresty/lualib/ -R

#tar 

