#!/bin/bash
echo -e "$(crontab -l 2>/dev/null | grep -v jellyfin-s3sync)\n*/5 * * * * /usr/bin/flock -n /home/ec2-user/jellyfin/scripts/s3sync.sh.lock -c \"/bin/sh /home/ec2-user/jellyfin/scripts/s3sync.sh\" #jellyfin-s3sync" | crontab -
