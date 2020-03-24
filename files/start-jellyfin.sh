#!/bin/bash
sudo service docker restart
docker ps -aq --filter "name=jellyfin" | grep -q . && docker stop jellyfin && docker rm -fv jellyfin
docker run -d \
 --volume ~/jellyfin/config:/config \
 --volume ~/jellyfin/cache:/cache \
 --volume ~/jellyfin/media:/media \
 --user 1000:1000 \
 --net=host \
 --restart=unless-stopped \
 --name jellyfin \
 jellyfin/jellyfin