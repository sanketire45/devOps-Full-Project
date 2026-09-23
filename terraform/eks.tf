# =============================================================================
# eks.tf  —  MASTERCLASS: the cluster + nodegroup (your 2 eksctl commands)
# =============================================================================
#
# This file builds the two things you created by hand with eksctl:
#   eksctl create cluster   --name=wanderlust --version=1.30 --without-nodegroup
#   eksctl create nodegroup --node-type=t2.large --nodes=2 --node-volume-size=29 ...
#
# A cluster has TWO halves:
#   1. CONTROL PLANE  = the brain (API server, scheduler, etcd). AWS runs & hides
#      it for you. You never SSH into it. This is `aws_eks_cluster`.
#   2. NODEGROUP      = the muscle (real EC2 machines that run your pods).
#      This is `aws_eks_node_group`.
# A control plane with no nodegroup can schedule nothing — that's why eksctl's
# first command used --without-nodegroup, then a second command added the nodes.
# =============================================================================


# -----------------------------------------------------------------------------
# NETWORKING: where does the cluster live?
# -----------------------------------------------------------------------------
# EKS must sit inside a VPC, and it REQUIRES subnets in at least 2 Availability
# Zones (so the control plane is highly available). eksctl builds a brand-new VPC
# for this. To stay minimal while learning, we REUSE the account's DEFAULT VPC,
# whose subnets already span multiple AZs. (The mega project builds a real VPC.)
#
# `data` = READ something that already exists in AWS. It does NOT create anything.
# Contrast with `resource`, which CREATES/manages a thing. Here we only look up
# the default VPC and its subnets so we can point the cluster at them.
data "aws_vpc" "default" {
  default = true # "give me the account's default VPC"
}

data "aws_subnets" "default" {
  # Filter all subnets down to only those belonging to that default VPC.
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id] # reference the VPC we just looked up
  }
}


# -----------------------------------------------------------------------------
# THE CLUSTER (control plane)  —  eksctl create cluster
# -----------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name    = var.cluster_name    # "wanderlust"
  version = var.cluster_version # Kubernetes version, e.g. "1.30"

  # The control plane WEARS the cluster IAM role we built in eks-iam.tf.
  # `.arn` is that role's unique AWS ID. This line is what connects "the brain"
  # to "its permissions."
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    # Which subnets the control plane's network interfaces live in (>= 2 AZs).
    subnet_ids = data.aws_subnets.default.ids

    # Expose the Kubernetes API server to the public internet, so `kubectl` from
    # your Jenkins box or laptop can reach it. (In hardened prod you'd make this
    # private + restrict CIDRs; public is fine for this learning cluster.)
    endpoint_public_access = true
  }

  # ORDERING MATTERS. Terraform builds things in parallel by default, but EKS
  # refuses to create a cluster whose role isn't ready. `depends_on` forces
  # Terraform to attach the policy FIRST, then create the cluster.
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}


# -----------------------------------------------------------------------------
# THE NODEGROUP (worker EC2s)  —  eksctl create nodegroup
# -----------------------------------------------------------------------------
# A "managed node group" = EKS creates and looks after a set of EC2 workers for
# you (an Auto Scaling Group under the hood). You just declare the shape.
resource "aws_eks_node_group" "this" {
  # Which cluster these nodes join. Referencing the cluster's .name here ALSO
  # tells Terraform "build the cluster before the nodegroup" automatically —
  # no explicit depends_on needed for this ordering.
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.cluster_name

  # The nodes WEAR the node IAM role from eks-iam.tf (join + CNI + ECR powers).
  node_role_arn = aws_iam_role.eks_node.arn

  # Put the workers in the same subnets as the cluster.
  subnet_ids = data.aws_subnets.default.ids

  instance_types = [var.node_instance_type] # ["t2.large"] — the machine size
  disk_size      = var.node_volume_size     # 29 GB root EBS volume per node

  # How many nodes, and the min/max the Auto Scaling Group may run.
  # Here all three are 2, so it's a fixed 2-node group (no autoscaling yet).
  scaling_config {
    desired_size = var.node_desired_size # start with 2
    min_size     = var.node_min_size     # never fewer than 2
    max_size     = var.node_max_size     # never more than 2
  }

  # eksctl's --ssh-access: allow SSH into the nodes using an existing key pair.
  # We reuse `terra-automate-key` (defined in ec2.tf) instead of creating a
  # separate eks-nodegroup-key. IMPORTANT: if you set ec2_ssh_key WITHOUT
  # source_security_group_ids, EKS opens port 22 to the WHOLE internet. So we
  # restrict the source to the Jenkins security group only.
  remote_access {
    ec2_ssh_key               = aws_key_pair.deployer.key_name
    source_security_group_ids = [aws_security_group.allow_user_to_connect.id]
  }

  # Nodes must have their permissions ATTACHED before they boot and try to join,
  # otherwise they fail to register with the control plane. Force that ordering.
  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}

# =============================================================================
# RECAP:
#   data sources READ the default VPC/subnets (no creation).
#   aws_eks_cluster       = the control-plane brain, wearing the cluster role.
#   aws_eks_node_group    = the EC2 muscle, wearing the node role.
#   depends_on / .name references enforce the build order:
#       IAM roles+policies  ->  cluster  ->  nodegroup.
#   After `terraform apply`, run the update-kubeconfig command from outputs.tf,
#   then `kubectl get nodes` shows your 2 workers Ready.
# =============================================================================
