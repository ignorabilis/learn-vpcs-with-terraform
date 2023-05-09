terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.15.0"
    }
  }

  required_version = "~> 1.4.0"

  cloud {
    organization = "ignorabilis"
    workspaces {
      name = "learn-vpcs-with-terraform"
    }
  }
}

