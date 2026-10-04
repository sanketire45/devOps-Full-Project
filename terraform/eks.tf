# =============================================================================
#  eks.tf  —  the cluster (control plane) + the worker nodes
# =============================================================================
#  🖥️  SAME AS RUNNING BY HAND:
#        eksctl create cluster   --name=wanderlust --version=1.34 --without-nodegroup
#        eksctl create nodegroup --node-type=c7i-flex.large --nodes=2 --node-volume-size=20
#
#  📖  WHAT IT DOES, SIMPLY:
#        A cluster = TWO halves:
#          1. CONTROL PLANE (the brain: API server, scheduler, etcd) → AWS runs &
#             hides it; you never SSH in.           → resource aws_eks_cluster
#          2. NODEGROUP (the muscle: real EC2 VMs that run your pods)
#                                                    → resource aws_eks_node_group
#        A brain with no nodes can run nothing — that's why there are two pieces.
#        We reuse the account's DEFAULT VPC (it already has subnets in 2+ AZs,
#        which EKS requires). `data` = just LOOK UP existing things, don't create.
# =============================================================================

# Look up the default VPC + its subnets to place the cluster in (>= 2 AZs needed).
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---- THE CLUSTER (control plane) ----
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn # wears the cluster role from eks-iam.tf

  vpc_config {
    subnet_ids             = data.aws_subnets.default.ids
    endpoint_public_access = true # so kubectl from your laptop can reach the API
  }

  # build the role's policy first, THEN the cluster
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# ---- THE NODEGROUP (worker EC2s) ----
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name # also makes TF build cluster first
  node_group_name = var.cluster_name
  node_role_arn   = aws_iam_role.eks_node.arn # wears the node role from eks-iam.tf
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = [var.node_instance_type] # c7i-flex.large
  disk_size      = var.node_volume_size     # 20 GB per node

  scaling_config {
    desired_size = var.node_desired_size # 2
    min_size     = var.node_min_size     # 2
    max_size     = var.node_max_size     # 2
  }

  # No SSH (remote_access) block on purpose: EKS nodes are managed via the API,
  # not SSH — and leaving it out keeps this state independent of the Jenkins box.

  # attach node permissions BEFORE the nodes boot & try to join
  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}

# Build order (enforced by the references above):
#   IAM roles + policies  →  cluster  →  nodegroup
# After apply: run the update-kubeconfig command (outputs.tf), then `kubectl get nodes`.
