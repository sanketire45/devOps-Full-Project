# =============================================================================
#  outputs.tf  —  useful values Terraform prints after `terraform apply`
# =============================================================================
#  🖥️  SAME AS RUNNING BY HAND:   (nothing — just prints facts back to you so
#        you don't have to hunt in the AWS console)
#
#  📖  WHAT IT DOES, SIMPLY:
#        Some facts are only known AFTER AWS builds things (the API endpoint, the
#        OIDC ARN). `output` blocks surface them in your terminal. The most useful
#        one hands you the exact `aws eks update-kubeconfig` line to copy-paste.
# =============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "The Kubernetes API server URL (what kubectl talks to)"
  value       = aws_eks_cluster.this.endpoint
}

# Copy-paste this after apply to point kubectl at the new cluster.
output "update_kubeconfig_command" {
  description = "Run this to configure kubectl for the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}

# The registered OIDC provider (from oidc.tf). Verify with:
#   aws iam list-open-id-connect-providers
output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider (IRSA roles trust this)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "The cluster's OIDC issuer URL"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
