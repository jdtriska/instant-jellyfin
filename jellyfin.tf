/**
 * This is our terraform config.
 * We use partial configuration here (see https://www.terraform.io/docs/backends/config.html).
 * This lets us provide the rest of the config variables via docker-compose
 *   from a .env file rather than hard coding them here.
 */
terraform {
  backend "s3" {}
  required_providers {
    aws = "~2.53"
  }
}

/*
 * This is our provider setup.
 * Feel free to try out other cloud providers using this as a template.
 */

provider "aws" {
  region = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

#  I add a couple of default folders to the bucket
#   to make it easier for you to get started.

/*
 * This will be our bucket to store our media in.
 * I am not including transcoding in this project, but FYI I use MakeMKV and
 *   Handbrake (NvEnc codec) and it all plays nicely together.
 * You should set up your folder structure in S3 through the AWS console exactly as
 *   you want it on your Jellyfin server.
 * See the Jellyfin docs for examples of how folders are usually laid out.
 */

resource "aws_s3_bucket" "jellyfin_media" {
  bucket = "${var.ENVIRONMENT}-jellyfin-media"
  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-media"
    Environment = var.ENVIRONMENT
  }
}

/**
 * This is our actual Jellyfin server.
 * The instance and storage size are configurable so you can tune the performance and
 *   cost exactly how you want.
 * The provisioner blocksa are there to:
 *   1. Copy our setup script to the server
 *   2. Run the setup script and start the Jellyfin server
 * If you need to remotely administer your server, please see the AWS docs for
 *   how to connect via SSH (I've left those ports open to the internet).
 */

resource "aws_instance" "jellyfin_server" {
  # ...

  provisioner "file" {
    content = <<EOF
sudo amazon-linux-extras enable nginx1
sudo yum install -y docker nginx
EOF
    destination = "/jellyfin/scripts/setup.sh"
  }

    provisioner "file" {
    content = <<EOF

(sudo crontab -l 2>/dev/null; echo "*/5 * * * * /path/to/job -with args") | crontab -
EOF
    destination = "/jellyfin/scripts/start-s3sync.sh"
  }

    provisioner "file" {
    content = <<EOF
docker run -d \
 --volume /jellyfin/config:/config \
 --volume /jellyfin/cache:/cache \
 --volume /jellyfin/media:/media \
 --user 1000:1000 \
 --net=host \
 --restart=unless-stopped \
 jellyfin/jellyfin
EOF
    destination = "/jellyfin/scripts/start-jellyfin.sh"
  }

    provisioner "file" {
    content = <<EOF

EOF
    destination = "/jellyfin/scripts/start-nginx.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sh /jellyfin/setup.sh",
      "sh /jellyfin/s3sync.sh",
      "sh /jellyfin/start-jellyfin.sh",
      "sh /jellyfin/start-nginx.sh"
    ]
  }

  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-server"
    Environment = var.ENVIRONMENT
  }
}