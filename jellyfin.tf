/**
 * This is our terraform config.
 * We use partial configuration here (see https://www.terraform.io/docs/backends/config.html).
 * This lets us provide the rest of the config variables via docker-compose
 *   from a .env file rather than hard coding them here.
 */
terraform {
  backend "s3" {}
  required_providers {
    aws = "~>2.53"
  }
}

/**
 * This is our provider setup.
 * Feel free to try out other cloud providers using this as a template.
 */

data "aws_route53_zone" "jellyfin_domain" {
  count = var.HOSTED_ZONE_ID == "" ? 0 : 1
  zone_id = var.HOSTED_ZONE_ID
}

provider "aws" {
  region = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

#  I add a couple of default folders to the bucket
#   to make it easier for you to get started.

/**
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
 * This sets up the permissions our EC2 instance will need to sync
 *   with S3.
 */

resource "aws_iam_role" "jellyfin_server_role" {
  name = "${var.ENVIRONMENT}-jellyfin-server-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-server-role"
    Environment = var.ENVIRONMENT
  }
}

resource "aws_iam_role_policy" "jellyfin_server_policy" {
  name = "${var.ENVIRONMENT}-jellyfin-server-policy"
  role = aws_iam_role.jellyfin_server_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        "Effect": "Allow",
        "Resource": [
          "${aws_s3_bucket.jellyfin_media.arn}",
          "${aws_s3_bucket.jellyfin_media.arn}/*"
        ]
      }
    ]
  }
  EOF
}

resource "aws_iam_instance_profile" "jellyfin_instance_profile" {
  name = "${var.ENVIRONMENT}-jellyfin-instance-profile"
  role = aws_iam_role.jellyfin_server_role.name
}

/**
 * We get the latest amazon linux 2 ami...
 */

data "aws_ami" "amazon_linux_2" {
 most_recent = true
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
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

resource "aws_security_group" "jellyfin_server_sg" {
  name = "${var.ENVIRONMENT}-jellyfin-server-sg"
  description = "Security group which allows SSH from anywhere and HTTP/S access from the load balancer"
  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.jellyfin_alb_sg.name]
  }
  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-server-sg"
    Environment = var.ENVIRONMENT
  }
}

resource "aws_instance" "jellyfin_server" {
  ami = data.aws_ami.amazon_linux_2.id
  instance_type = var.EC2_INSTANCE_TYPE
  iam_instance_profile = aws_iam_instance_profile.jellyfin_instance_profile.name
  root_block_device {
    volume_size = var.EBS_VOLUME_SIZE
  }
  security_groups = []
  provisioner "file" {
    content = <<EOF
server {
  listen 80;
    server_name ${trimsuffix(data.aws_route53_zone.jellyfin_domain.name,".")};
  location / {
    # Proxy main Jellyfin traffic
    proxy_pass http://localhost:8096/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Protocol $scheme;
    proxy_set_header X-Forwarded-Host $http_host;

    # Disable buffering when the nginx proxy gets very resource heavy upon streaming
    proxy_buffering off;
  }
  location /socket {
    # Proxy Jellyfin Websockets traffic
    proxy_pass http://localhost:8096/socket;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Protocol $scheme;
    proxy_set_header X-Forwarded-Host $http_host;
  }
}
EOF
    destination = "/etc/nginx/conf.d/instant-jellyfin.conf"
  }

  provisioner "file" {
    content = <<EOF
#!/bin/bash
amazon-linux-extras enable nginx1
yum install -y docker nginx
EOF
    destination = "/jellyfin/scripts/setup.sh"
  }

  provisioner "file" {
    content = <<EOF
#!/bin/bash
echo -e "$(crontab -u root -l | grep -v jellyfin-s3-sync)\n* * * * * /bin/bash /jellyfin/scripts/s3sync.sh #jellyfin-s3-sync" | crontab -u root -
EOF
    destination = "/jellyfin/scripts/start-s3sync.sh"
  }

  provisioner "file" {
    content = <<EOF
#!/bin/bash
aws s3 sync s3://${aws_s3_bucket.jellyfin_media.id} /jellyfin/media --delete
EOF
    destination = "/jellyfin/scripts/s3sync.sh"
  }

  provisioner "file" {
    content = <<EOF
#!/bin/bash
docker ps -aq --filter "name=jellyfin" | grep -q . && docker stop jellyfin && docker rm -fv jellyfin
sudo docker run -d \
 --volume /jellyfin/config:/config \
 --volume /jellyfin/cache:/cache \
 --volume /jellyfin/media:/media \
 --user 1000:1000 \
 --net=host \
 --restart=unless-stopped \
 --name jellyfin \
 jellyfin/jellyfin
EOF
    destination = "/jellyfin/scripts/start-jellyfin.sh"
  }

  provisioner "file" {
    content = <<EOF
#!/bin/bash
service nginx restart
EOF
    destination = "/jellyfin/scripts/start-nginx.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo /bin/bash /jellyfin/setup.sh",
      "sudo /bin/bash /jellyfin/start-s3sync.sh",
      "sudo /bin/bash /jellyfin/start-jellyfin.sh",
      "sudo /bin/bash /jellyfin/start-nginx.sh"
    ]
  }

  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-server"
    Environment = var.ENVIRONMENT
  }
}

/**
 * Next we'll create an SSL certificate for our domain, and the
 *   load balancer which will serve the certificate and route
 *   traffic to our EC2 instance.
 * There is a lot of networking below, as well as optional resources for
 *   if you've provided a domain.
 */

resource "aws_security_group" "jellyfin_alb_sg" {
  name = "${var.ENVIRONMENT}-jellyfin-alb-sg"
  description = "Security group which allows HTTP/S access from anywhere"
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-server-sg"
    Environment = var.ENVIRONMENT
  }
}

resource "aws_acm_certificate" "jellyfin_cert" {
  domain_name       = trimsuffix(data.aws_route53_zone.jellyfin_domain.name,".")
  validation_method = "DNS"
}

resource "aws_route53_record" "jellyfin_cert_validation_record" {
  name    = aws_acm_certificate.jellyfin_cert.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.jellyfin_cert.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.jellyfin_domain.id
  records = [aws_acm_certificate.jellyfin_cert.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "jellyfin_cert_validation" {
  certificate_arn         = aws_acm_certificate.jellyfin_cert.arn
  validation_record_fqdns = [aws_route53_record.jellyfin_cert_validation_record.fqdn]
}

resource "aws_lb" "jellyfin_alb" {
  name = "${var.ENVIRONMENT}-jellyfin-alb"
  load_balancer_type = "application"
  internal = false
  security_groups = [aws_security_group.jellyfin_alb_sg.id]

  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-alb"
    Environment = var.ENVIRONMENT
  }
}

resource "aws_lb_target_group" "jellyfin_tg" {
  name     = "${var.ENVIRONMENT}-jellyfin-tg"
  port     = 80
  protocol = "HTTP"

  health_check {
    enabled = true
    path = "/"
    matcher = "200"
  }

  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-tg"
    Environment = var.ENVIRONMENT
  }
}

resource "aws_lb_listener" "jellyfin_http" {
  count = var.HOSTED_ZONE_ID == "" ? 0 : 1
  load_balancer_arn = aws_lb.jellyfin_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "jellyfin_http_no_ssl" {
  count = var.HOSTED_ZONE_ID == "" ? 1 : 0
  load_balancer_arn = aws_lb.jellyfin_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jellyfin_tg.arn
  }
}

resource "aws_lb_listener" "jellyfin_https" {
  count = var.HOSTED_ZONE_ID == "" ? 0 : 1
  load_balancer_arn = aws_lb.jellyfin_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate_validation.jellyfin_cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jellyfin_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "jellyfin_server_attachment" {
  target_group_arn = aws_lb_target_group.jellyfin_tg.arn
  target_id        = aws_instance.jellyfin_server.id
  port             = 80
}

/**
 * Finally, with the networking set up, we can put our domain in front of our load balancer.
 * We only do this if you provided a domain.
 */

resource "aws_route53_record" "jellyfin_domain_record" {
  count = var.HOSTED_ZONE_ID == "" ? 0 : 1
  zone_id = data.aws_route53_zone.jellyfin_domain.zone_id
  name    = trimsuffix(data.aws_route53_zone.jellyfin_domain.name,".")
  type    = "A"
  alias {
    name                   = aws_lb.jellyfin_alb.dns_name
    zone_id                = aws_lb.jellyfin_alb.zone_id
    evaluate_target_health = true
  }
}