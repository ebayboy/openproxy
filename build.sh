#!/bin/bash

#git submodule foreach git pull
git submodule foreach  --recursive 'tag="$(git config -f $toplevel/.gitmodules submodule.$name.tag)";[[ -n $tag ]] && git reset --hard  $tag || echo "this module has no tag"'

exit 0;

INSTALL_PATH=/usr/local/myresty
BUILDROOT=./build

#checkout code
git checkout -b v1.15.8.2 v1.15.8.2

rf -rf $BUILDROOT &&  mkdir $BUILDROOT

#copy code
cp -afR vendors/openresty/ $BUILDROOT
cp -afR 3Party/ $BUILDROOT

cd $BUILDROOT

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
    --add-module=./3Party/nginx-auth-ldap   \
    --add-module=./3Party/nginx-sticky-module-ng    

gmake && gmake install

#install my lua_modules
cd ./3Party/lua_modules 
sh ./build_lua_modules.sh  
cp lib/* /usr/local/myresty/lualib/ -R
cd -

cd ../

#tar 

