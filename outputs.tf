output "jellyfin_endpoint" {
  value = var.HOSTED_ZONE_ID == "" ? aws_lb.jellyfin_alb.dns_name : trimsuffix(aws_route53_record.jellyfin_domain_record.fqdn,".")
}

output "jellyfin_server_ssh_endpoint" {
  value = aws_instance.jellyfin_server.public_dns
}