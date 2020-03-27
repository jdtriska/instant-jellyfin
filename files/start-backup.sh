#!/bin/bash
echo -e "$(crontab -l 2>/dev/null | grep -v jellyfin-backup)\n0 * * * * /usr/bin/flock -n /home/ec2-user/jellyfin/scripts/backup.sh.lock -c \"/bin/sh /home/ec2-user/jellyfin/scripts/backup.sh\" #jellyfin-backup" | crontab -
