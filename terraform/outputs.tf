# =============================================================================
# outputs.tf  —  MASTERCLASS: values Terraform prints back to you after apply
# =============================================================================
#
# WHY OUTPUTS EXIST:
#   After `terraform apply`, some facts are only known once AWS creates the
#   resources (like the cluster's API endpoint URL). `output` blocks pull those
#   facts back out and print them in your terminal — so you don't have to dig
#   through the AWS console to find them. They can also feed other tools/modules.
# =============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "The Kubernetes API server URL (what kubectl talks to)"
  value       = aws_eks_cluster.this.endpoint
}

# The single most useful output: copy-paste this line after apply to point
# kubectl at the brand-new cluster. It writes the cluster's address + auth into
# your local ~/.kube/config so `kubectl get nodes` just works.
output "update_kubeconfig_command" {
  description = "Run this to configure kubectl for the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}
