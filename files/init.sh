#!/bin/bash
sudo mv /tmp/instant-jellyfin.conf /etc/nginx/conf.d/instant-jellyfin.conf
mv /tmp/start-s3sync.sh ~/jellyfin/scripts/start-s3sync.sh
mv /tmp/s3sync.sh ~/jellyfin/scripts/s3sync.sh
mv /tmp/start-jellyfin.sh ~/jellyfin/scripts/start-jellyfin.sh
mv /tmp/start-nginx.sh ~/jellyfin/scripts/start-nginx.sh
sudo dos2unix /etc/nginx/conf.d/instant-jellyfin.conf
dos2unix ~/jellyfin/scripts/start-s3sync.sh
dos2unix ~/jellyfin/scripts/s3sync.sh
dos2unix ~/jellyfin/scripts/start-jellyfin.sh
dos2unix ~/jellyfin/scripts/start-nginx.sh
/bin/bash ~/jellyfin/scripts/start-s3sync.sh
/bin/bash ~/jellyfin/scripts/start-jellyfin.sh
/bin/bash ~/jellyfin/scripts/start-nginx.sh