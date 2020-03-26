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

locals {
  server_name = var.HOSTED_ZONE_ID == "" ? "~^${aws_lb.jellyfin_alb.name}.*\\.elb\\.amazonaws.com$" : trimsuffix(data.aws_route53_zone.jellyfin_domain.0.name,".") 
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
  owners = ["amazon"]
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
 * The provisioner blocks are there to:
 *   1. Copy our setup script to the server
 *   2. Run the setup script and start the Jellyfin server
 * If you need to remotely administer your server, please see the AWS docs for
 *   how to connect via SSH (I've left those ports open to the internet).
 */

resource "aws_security_group" "jellyfin_server_sg" {
  name = "${var.ENVIRONMENT}-jellyfin-server-sg"
  description = "Security group which allows SSH from anywhere and HTTP/S access from the load balancer"
  vpc_id = aws_vpc.jellyfin_vpc.id
  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.jellyfin_alb_sg.id]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-server-sg"
    Environment = var.ENVIRONMENT
  }
}

resource "aws_key_pair" "jellyfin_keys" {
  key_name   = "jellyfin-key"
  public_key = file(".ssh/jellyfin-key.pub")
}

resource "aws_eip" "jellyfin_eip" {
  instance = aws_instance.jellyfin_server.id
  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin_eip"
    Environment = var.ENVIRONMENT
  }
  vpc = true
}

resource "aws_instance" "jellyfin_server" {
  key_name = aws_key_pair.jellyfin_keys.key_name
  ami = data.aws_ami.amazon_linux_2.id
  instance_type = var.EC2_INSTANCE_TYPE
  iam_instance_profile = aws_iam_instance_profile.jellyfin_instance_profile.name
  associate_public_ip_address = true
  root_block_device {
    volume_size = var.EBS_ROOT_VOLUME_SIZE
  }
  ebs_block_device {
    device_name = local.EBS_Device 
    volume_size = var.EBS_MEDIA_VOLUME_SIZE
    volume_type = var.EBS_MEDIA_VOLUME_TYPE
  }

  security_groups = [aws_security_group.jellyfin_server_sg.id]
  subnet_id = aws_subnet.jellyfin_a.id
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file(".ssh/jellyfin-key")
    host     = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir ~/jellyfin",
      "mkdir ~/jellyfin/scripts",
      "mkdir ~/jellyfin/media",
      "mkdir ~/jellyfin/cache",
      "mkdir ~/jellyfin/config",
      "sudo amazon-linux-extras enable nginx1",
      "sudo yum install -y docker nginx dos2unix",
      "sudo usermod -a -G docker ec2-user",
      "sudo systemctl enable docker",
      "sudo systemctl enable nginx"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "EBS_DEVICE_NAME=$(lsblk | grep ${var.EBS_MEDIA_VOLUME_SIZE}G | awk '{print $1}')",
      "sudo mkfs -t xfs /dev/$${EBS_DEVICE_NAME}",
      "EBS_DEVICE_UUID=$(sudo blkid | grep $${EBS_DEVICE_NAME} | awk -F'\"' '{print $2}')",
      "sudo echo -e \"UUID=$${EBS_DEVICE_UUID} /home/ec2-user/jellyfin/media  xfs  defaults,nofail  0  2\" | sudo tee -a /etc/fstab",
      "sudo mount -a",
      "sudo chown -R ec2-user /home/ec2-user/jellyfin/media"
    ]
  }

  // Creates nginx conf file for jellyfin server based on ALB or Domain name
  provisioner "file" {
    content = templatefile("templates/server.conf.tmpl", { server_name = local.server_name })
    destination = "/tmp/instant-jellyfin.conf"
  }

  // Lays down cron for syncing files form s3 bucket to local storage
  provisioner "file" {
    content = file("files/start-sync.sh") 
    destination = "/tmp/start-s3sync.sh"
  }

  // Creates cron job script with bucket variable
  provisioner "file" {
    content = templatefile("templates/s3sync.sh.tmpl", { BUCKET = aws_s3_bucket.jellyfin_media.id })
    destination = "/tmp/s3sync.sh"
  }

  // Lays down docker script
  provisioner "file" {
    content = file("files/start-jellyfin.sh")
    destination = "/tmp/start-jellyfin.sh"
  }

  // Starts Nginx with jellyfin conf
  provisioner "file" {
    content = file("files/start-nginx.sh")
    destination = "/tmp/start-nginx.sh"
  }

   provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/instant-jellyfin.conf /etc/nginx/conf.d/instant-jellyfin.conf",
      "mv /tmp/start-s3sync.sh ~/jellyfin/scripts/start-s3sync.sh",
      "mv /tmp/s3sync.sh ~/jellyfin/scripts/s3sync.sh",
      "mv /tmp/start-jellyfin.sh ~/jellyfin/scripts/start-jellyfin.sh",
      "mv /tmp/start-nginx.sh ~/jellyfin/scripts/start-nginx.sh",
      "sudo dos2unix /etc/nginx/conf.d/instant-jellyfin.conf",
      "dos2unix ~/jellyfin/scripts/start-s3sync.sh",
      "dos2unix ~/jellyfin/scripts/s3sync.sh",
      "dos2unix ~/jellyfin/scripts/start-jellyfin.sh",
      "dos2unix ~/jellyfin/scripts/start-nginx.sh",
      "/bin/bash ~/jellyfin/scripts/start-s3sync.sh",
      "/bin/bash ~/jellyfin/scripts/start-jellyfin.sh",
      "/bin/bash ~/jellyfin/scripts/start-nginx.sh"
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

resource "aws_vpc" "jellyfin_vpc" { 
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.ENVIRONMENT}-jellyfin_vpc"
    Environment = var.ENVIRONMENT
}
}

resource "aws_internet_gateway" "jellyfin_igw" {
  vpc_id = aws_vpc.jellyfin_vpc.id
  tags = {
    Name = "${var.ENVIRONMENT}-jellyfin_igw"
    Environment = var.ENVIRONMENT
}
}

resource "aws_default_route_table" "jellyfin_route" {
  default_route_table_id = aws_vpc.jellyfin_vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jellyfin_igw.id
  }
  tags = {
    Name = "${var.ENVIRONMENT}-jellyfin_route"
    Environment = var.ENVIRONMENT
}
}

resource "aws_subnet" "jellyfin_a" {
  vpc_id     = aws_vpc.jellyfin_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.AWS_REGION}a"
  tags = {
    Name = "${var.ENVIRONMENT}-jellyfin_a"
    Environment = var.ENVIRONMENT
}
}

resource "aws_subnet" "jellyfin_b" {
  vpc_id     = aws_vpc.jellyfin_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.AWS_REGION}b"
  tags = {
    Name = "${var.ENVIRONMENT}-jellyfin_b"
    Environment = var.ENVIRONMENT
  }
}

resource "aws_security_group" "jellyfin_alb_sg" {
  name = "${var.ENVIRONMENT}-jellyfin-alb-sg"
  description = "Security group which allows HTTP/S access from anywhere"
  vpc_id = aws_vpc.jellyfin_vpc.id
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-server-sg"
    Environment = var.ENVIRONMENT
  }
}

resource "aws_acm_certificate" "jellyfin_cert" {
  count = var.HOSTED_ZONE_ID == "" ? 0 : 1
  domain_name       = trimsuffix(data.aws_route53_zone.jellyfin_domain.0.name,".")
  validation_method = "DNS"
}

resource "aws_route53_record" "jellyfin_cert_validation_record" {
  count = var.HOSTED_ZONE_ID == "" ? 0 : 1
  name    = aws_acm_certificate.jellyfin_cert.0.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.jellyfin_cert.0.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.jellyfin_domain.0.id
  records = [aws_acm_certificate.jellyfin_cert.0.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "jellyfin_cert_validation" {
  count = var.HOSTED_ZONE_ID == "" ? 0 : 1
  certificate_arn         = aws_acm_certificate.jellyfin_cert.0.arn
  validation_record_fqdns = [aws_route53_record.jellyfin_cert_validation_record.0.fqdn]
}

resource "aws_lb" "jellyfin_alb" {
  name = "${var.ENVIRONMENT}-jellyfin-alb"
  load_balancer_type = "application"
  internal = false
  security_groups = [aws_security_group.jellyfin_alb_sg.id]
  subnets = [aws_subnet.jellyfin_a.id, aws_subnet.jellyfin_b.id]
  tags = {
    Name        = "${var.ENVIRONMENT}-jellyfin-alb"
    Environment = var.ENVIRONMENT
  }
}

resource "aws_lb_target_group" "jellyfin_tg" {
  name     = "${var.ENVIRONMENT}-jellyfin-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.jellyfin_vpc.id

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
  certificate_arn = aws_acm_certificate_validation.jellyfin_cert_validation.0.certificate_arn

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
  zone_id = data.aws_route53_zone.jellyfin_domain.0.zone_id
  name    = trimsuffix(data.aws_route53_zone.jellyfin_domain.0.name,".")
  type    = "A"
  alias {
    name                   = aws_lb.jellyfin_alb.dns_name
    zone_id                = aws_lb.jellyfin_alb.zone_id
    evaluate_target_health = true
  }
}