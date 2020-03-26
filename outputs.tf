output "jellyfin_endpoint" {
  value = var.HOSTED_ZONE_ID == "" ? aws_lb.jellyfin_alb.dns_name : trimsuffix(aws_route53_record.jellyfin_domain_record.0.fqdn,".")
}

output "jellyfin_server_ssh_command" {
  value = "ssh -i \"./.ssh/jellyfin-key\" ec2-user@${aws_eip.jellyfin_eip.public_ip}"
}

output "jellyfin_media_bucket" {
  value = aws_s3_bucket.jellyfin_media.arn
}
}