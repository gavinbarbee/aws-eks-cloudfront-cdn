data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_response_headers_policy" "security" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_distribution" "listings" {
  #checkov:skip=CKV_AWS_174:No custom domain, so no ACM certificate for HTTPS on the origin or a custom viewer certificate; viewers still get HTTPS from CloudFront
  #checkov:skip=CKV2_AWS_42:No custom domain, so no ACM certificate for HTTPS on the origin or a custom viewer certificate; viewers still get HTTPS from CloudFront
  #checkov:skip=CKV_AWS_68:WAF adds monthly cost; origin is protected by the CloudFront prefix list and a secret header instead
  #checkov:skip=CKV2_AWS_47:WAF adds monthly cost; origin is protected by the CloudFront prefix list and a secret header instead
  #checkov:skip=CKV_AWS_86:Access logging needs extra S3 log buckets, out of scope for this lab
  #checkov:skip=CKV_AWS_310:Origin failover needs a second origin, out of scope for a single-region lab
  enabled             = true
  default_root_object = "index.html"
  comment             = "cdn-gavinbarbee-listings"
  price_class         = "PriceClass_100" # North America and Europe edge locations
  http_version        = "http2and3"
  is_ipv6_enabled     = true

  origin {
    domain_name = aws_lb.listings.dns_name
    origin_id   = "alb-listings"

    # No custom domain means no ACM certificate for the ALB, so CloudFront reaches it over HTTP.
    # Viewers still get HTTPS from CloudFront's default certificate.
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_verify.result
    }
  }

  # CachingOptimized honors the origin's Cache-Control headers:
  # HTML is cached for 60 seconds, /assets/ for a year
  default_cache_behavior {
    target_origin_id           = "alb-listings"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id
    compress                   = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
