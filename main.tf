data "aws_region" "current" {}
data "aws_availability_zones" "current" {}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main-learn-vpcs" {
  cidr_block = "10.0.0.0/22"

  tags = {
    purpose = "learn vpcs"
  }
}
