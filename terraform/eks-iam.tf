# =============================================================================
# eks-iam.tf  —  MASTERCLASS: the IAM roles eksctl created INVISIBLY for you
# =============================================================================
#
# THE BIG IDEA (read this first):
#   AWS never lets a machine "just do things." Before the EKS control plane can
#   create load balancers for you, or a worker EC2 can join the cluster, AWS asks:
#   "WHO are you, and WHAT are you allowed to do?"
#   An IAM ROLE answers both. eksctl built these roles behind your back. Here we
#   build them ourselves so nothing is hidden.
#
# ROLE vs USER (the mental model):
#   - An IAM USER  = a permanent identity for a HUMAN (you, with a password/keys).
#   - An IAM ROLE  = a costume a MACHINE/SERVICE temporarily WEARS to get powers.
#     Nobody logs in as a role. A service "assumes" it, wears it for a task,
#     and AWS hands it short-lived credentials. No passwords, no stored keys.
#
# EVERY ROLE HAS TWO SEPARATE POLICIES — don't confuse them:
#   1. TRUST policy  (assume_role_policy)  = WHO is allowed to wear this costume.
#   2. PERMISSION policy (attachments)     = WHAT the wearer can then do.
#   Think: (1) who may put on the uniform, (2) what the uniform lets them do.
# =============================================================================


# -----------------------------------------------------------------------------
# 1. CLUSTER ROLE — worn by the EKS CONTROL PLANE itself
# -----------------------------------------------------------------------------
# The control plane (the AWS-managed brain of your cluster) acts on your behalf:
# it wires up networking, talks to EC2, etc. To do that it must WEAR a role.

# ---- TRUST policy: WHO may wear this role? ----
# This is a "policy document" — a JSON permission statement. We write it in HCL
# and Terraform turns it into JSON for us (cleaner than hand-writing JSON).
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"] # "sts:AssumeRole" = the API call "let me wear this role"
    principals {
      type = "Service"
      # The PRINCIPAL is who is allowed to assume it. Here it's an AWS SERVICE,
      # identified by its service name. "eks.amazonaws.com" = the EKS service.
      # So this reads: "Allow the EKS service to wear this role." Nothing else can.
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# The role itself. Its ONLY built-in rule is the trust policy above (who can wear
# it). It has NO powers yet — powers come from the attachment below.
resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}

# ---- PERMISSION policy: WHAT can the wearer do? ----
# We attach an AWS-MANAGED policy (a ready-made permission set AWS maintains).
# "AmazonEKSClusterPolicy" is the exact set of permissions a control plane needs.
# Without this, the cluster would refuse to create.
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


# -----------------------------------------------------------------------------
# 2. NODE ROLE — worn by each WORKER EC2 instance
# -----------------------------------------------------------------------------
# Your worker nodes are just EC2 machines. For them to behave as Kubernetes
# workers they need permissions — to register with the cluster, to give pods
# network IPs, and to pull container images. That's what this role grants.

# ---- TRUST policy: WHO may wear it? ----
# This time the principal is the EC2 service ("ec2.amazonaws.com"), because the
# wearer is an EC2 instance, not the EKS service. Same pattern, different service.
data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
}

# ---- PERMISSION policies: the 3 things EVERY worker node must be able to do ----

# (a) Join the cluster and be managed by it (register with the control plane,
#     report health, receive pod assignments).
resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# (b) Give pods real VPC IP addresses. EKS uses the "VPC CNI" plugin, which hands
#     each pod an actual IP from your VPC (this is why an ALB can talk straight to
#     pod IPs later). That plugin needs this permission to allocate those IPs.
resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# (c) Pull container images from ECR (Amazon's private image registry).
#     Read-only: nodes only need to DOWNLOAD images, never push them.
resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# =============================================================================
# RECAP:
#   Two roles. Each = a TRUST policy (who may wear it) + PERMISSION policies
#   (what it can do). Cluster role is worn by the EKS service; node role is worn
#   by EC2 workers. eksctl made all of this silently — now you can see and control
#   every line of it. This is the exact thing interviewers mean by "you understand
#   EKS IAM," and it's the foundation IRSA builds on later.
# =============================================================================
