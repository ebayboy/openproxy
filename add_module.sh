#!/bin/bash


if (($# != 2));then
    echo "Usage: git submodule add <仓库地址> <本地路径>";
    exit 1;
fi

git submodule add $1 $2

