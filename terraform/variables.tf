# =============================================================================
# variables.tf  —  MASTERCLASS: the tuneable knobs of your infrastructure
# =============================================================================
#
# WHY VARIABLES EXIST:
#   Instead of hardcoding "wanderlust" or "t2.large" in ten places, you define
#   each value ONCE here as a variable, then reference it as `var.<name>`
#   everywhere. Change it in one spot -> it changes everywhere. This is how real
#   Terraform stays reusable (the same code can build dev/qa/prod by swapping
#   values). `default` = the value used if you don't override it.
# =============================================================================

variable "aws_region" {
  description = "AWS region where resources will be provisioned"
  default     = "us-east-2"
}

variable "ami_id" {
  description = "AMI ID for the Jenkins EC2 instance (see ec2.tf)"
  default     = "ami-0b6d9d3d33ba97d99"
}

variable "instance_type" {
  description = "Instance type for the Jenkins EC2 instance"
  default     = "m7i-flex.large"

}

# ---------------------------------------------------------------------------
# EKS knobs — each mirrors one eksctl flag from README.md, so you can see
# exactly which CLI flag became which Terraform value.
# ---------------------------------------------------------------------------
variable "cluster_name" {
  description = "EKS cluster name (eksctl --name)"
  default     = "wanderlust"
}

variable "cluster_version" {
  description = "Kubernetes version for the control plane. NOTE (verified Sep 2026): latest EKS version is 1.36; standard support is ~1.34-1.36. Versions <= 1.33 are on EXTENDED support (extra $ surcharge) or retired. The tutorial used 1.30 — do NOT use it now. Pick a version your console lists under standard support; match this to what you actually create."
  default     = "1.34"
}

variable "node_instance_type" {
  description = "Worker node machine size (eksctl --node-type)"
  default     = "c7i-flex.large"
}

variable "node_desired_size" {
  description = "How many worker nodes to start with (eksctl --nodes)"
  default     = 2
}

variable "node_min_size" {
  description = "Fewest worker nodes the group may scale to (eksctl --nodes-min)"
  default     = 2
}

variable "node_max_size" {
  description = "Most worker nodes the group may scale to (eksctl --nodes-max)"
  default     = 2
}

variable "node_volume_size" {
  description = "Root EBS disk size in GB per worker node (eksctl --node-volume-size)"
  default     = 20
}
