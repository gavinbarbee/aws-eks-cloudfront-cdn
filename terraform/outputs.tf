output "cluster_name" {
  value = module.eks.cluster_name
}

output "region" {
  value = var.region
}

output "ecr_repository_url" {
  value = aws_ecr_repository.listings.repository_url
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.listings.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.listings.id
}

output "alb_dns_name" {
  value = aws_lb.listings.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.listings.arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
