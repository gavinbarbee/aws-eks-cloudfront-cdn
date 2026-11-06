terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "aws-eks-cloudfront-cdn"
      Owner     = "gavinbarbee"
      ManagedBy = "Terraform"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "github_owner" {
  type    = string
  default = "gavinbarbee"
}

variable "github_owner_id" {
  type    = string
  default = "177060158"
}

variable "github_repo" {
  type    = string
  default = "aws-eks-cloudfront-cdn"
}

variable "github_repo_id" {
  description = "Numeric repo ID from: gh api repos/gavinbarbee/aws-eks-cloudfront-cdn --jq .id"
  type        = string
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Remote state bucket (S3 native locking, no DynamoDB table needed)
resource "aws_s3_bucket" "tfstate" {
  bucket        = "gavinbarbee-cdn-tfstate-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# An account can only have one OIDC provider per URL. Lab 1's bootstrap created it,
# so this lab looks it up instead of creating a second one.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # The repo uses GitHub immutable subject claims, so the sub includes owner and repo IDs.
    # A renamed or recreated repo with the same name cannot assume this role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "role-gavinbarbee-github-actions-cdn"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

# Lab scope: broad rights so Terraform can create VPC, EKS, IAM, ALB, CloudFront, and ECR.
# Production would scope this to the exact services and resources.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
