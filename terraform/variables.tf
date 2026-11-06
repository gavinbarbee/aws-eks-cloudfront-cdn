variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "kubernetes_version" {
  description = "Use the newest version in EKS standard support to avoid extended-support charges"
  type        = string
  default     = "1.35"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "admin_principal_arn" {
  description = "IAM role or user ARN (no path) that gets cluster-admin for local kubectl"
  type        = string
}

locals {
  cluster_name = "eks-gavinbarbee-cdn"
}
