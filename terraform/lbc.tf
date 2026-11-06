# IAM role for the AWS Load Balancer Controller, delivered to its pod through EKS Pod Identity.
# The controller registers pod IPs in the Terraform-managed target group (TargetGroupBinding).
module "lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.12"

  name = "aws-lbc-gavinbarbee"

  attach_aws_lb_controller_policy = true

  associations = {
    controller = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }
}
