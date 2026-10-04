# =============================================================================
#  terraform.tf  —  which "plugins" (providers) Terraform downloads
# =============================================================================
#  🖥️  SAME AS RUNNING BY HAND:   (nothing — this is setup, not an action)
#        it's like telling your laptop "install the AWS CLI, the kubectl/helm
#        tools, etc." BEFORE you can run any command.
#
#  📖  WHAT IT DOES, SIMPLY:
#        Terraform can't talk to AWS/Kubernetes/Helm on its own — it needs a
#        "provider" plugin for each. This file lists the 5 we use:
#          • aws        → create AWS things (EKS, IAM, VPC lookups)
#          • tls        → read the OIDC issuer's certificate (for oidc.tf)
#          • kubernetes → talk to the cluster's API
#          • helm       → install Helm charts into the cluster
#          • http       → download the LB-controller's IAM policy JSON
#        `terraform init` reads this file and downloads them.
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.65.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

# Which AWS region everything is built in (comes from variables.tf).
provider "aws" {
  region = var.aws_region
}
