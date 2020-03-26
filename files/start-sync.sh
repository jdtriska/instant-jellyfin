#!/bin/bash
echo -e "$(crontab -l 2>/dev/null | grep -v jellyfin-s3-sync)\n*/5 * * * * /usr/bin/flock /bin/bash ~/jellyfin/scripts/s3sync.sh #jellyfin-s3-sync" | crontab -
