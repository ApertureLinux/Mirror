#!/bin/bash

cd "$1"
PATH= source PKGBUILD
if [[ -n "$epoch" ]]; then
    fullver=$epoch:$pkgver-$pkgrel
else
    fullver=$pkgver-$pkgrel
fi
printf %s\\t%s\\n "${pkgbase:-$pkgname}" "$fullver"  
