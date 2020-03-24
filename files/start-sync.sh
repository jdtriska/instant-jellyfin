#!/bin/bash
echo -e "$(crontab -l 2>/dev/null | grep -v jellyfin-s3-sync)\n*/5 * * * * /usr/bin/flock -x /var/log/jellyfin-s3-sync /bin/bash ~/jellyfin/scripts/s3sync.sh #jellyfin-s3-sync" | crontab -