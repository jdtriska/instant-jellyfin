#!/bin/bash
mkdir ~/jellyfin
mkdir ~/jellyfin/scripts
mkdir ~/jellyfin/media
mkdir ~/jellyfin/cache
mkdir ~/jellyfin/config
sudo amazon-linux-extras enable nginx1
sudo yum install -y docker nginx dos2unix
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker
sudo systemctl enable nginx