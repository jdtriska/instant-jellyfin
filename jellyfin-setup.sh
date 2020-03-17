#!/bin/bash

# Jellyfin runs in docker, you need docker
yum install -y docker
# Set up an ongoing job to sync with S3
# (crontab -l 2>/dev/null; echo "*/5 * * * * /path/to/job -with args") | crontab -
