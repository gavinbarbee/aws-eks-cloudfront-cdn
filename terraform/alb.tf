# AWS-managed list of CloudFront origin-facing IP ranges
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  name        = "sg-gavinbarbee-alb"
  description = "ALB accepts HTTP only from CloudFront"
  vpc_id      = module.vpc.vpc_id
}

# Layer 1 of origin protection: only CloudFront IP ranges can reach the ALB
resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  #checkov:skip=CKV_AWS_260:False positive - ingress is limited to the CloudFront managed prefix list, not 0.0.0.0/0
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from CloudFront origin-facing ranges"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_pods" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to listings pods"
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

# Pods use the node security group (VPC CNI), so allow the ALB in on the container port
resource "aws_vpc_security_group_ingress_rule" "pods_from_alb" {
  security_group_id            = module.eks.node_security_group_id
  description                  = "Listings pods from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_lb" "listings" {
  #checkov:skip=CKV2_AWS_20:No custom domain, so no ACM certificate for HTTPS on the origin or a custom viewer certificate; viewers still get HTTPS from CloudFront
  #checkov:skip=CKV2_AWS_28:WAF adds monthly cost; origin is protected by the CloudFront prefix list and a secret header instead
  #checkov:skip=CKV_AWS_91:Access logging needs extra S3 log buckets, out of scope for this lab
  #checkov:skip=CKV_AWS_150:Deletion protection would block same-day lab teardown
  name                       = "alb-gavinbarbee-listings"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = module.vpc.public_subnets
  drop_invalid_header_fields = true
}

# Pods are registered here by the controller's TargetGroupBinding, not by Terraform
resource "aws_lb_target_group" "listings" {
  #checkov:skip=CKV_AWS_378:No custom domain, so no ACM certificate for HTTPS on the origin or a custom viewer certificate; viewers still get HTTPS from CloudFront
  name                 = "tg-gavinbarbee-listings"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  deregistration_delay = 30

  health_check {
    path    = "/"
    matcher = "200"
  }
}

# Layer 2 of origin protection: a secret header only CloudFront knows
resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:No custom domain, so no ACM certificate for HTTPS on the origin or a custom viewer certificate; viewers still get HTTPS from CloudFront
  #checkov:skip=CKV_AWS_103:No custom domain, so no ACM certificate for HTTPS on the origin or a custom viewer certificate; viewers still get HTTPS from CloudFront
  load_balancer_arn = aws_lb.listings.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Direct access blocked"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "from_cloudfront" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.listings.arn
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.origin_verify.result]
    }
  }
}
