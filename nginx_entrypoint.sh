#!/bin/sh
WWW_DIR=/usr/share/nginx/html
for file in $(find "$WWW_DIR" -type f)
do
    sed "s@\\\$#SDOW_API_URL#\\\$@$SDOW_API_URL@" -i "$file"
done

[ -z "$@" ] && nginx -g 'daemon off;' || $@
