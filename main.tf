data "aws_region" "current" {}
data "aws_availability_zones" "current" {
    state = "available"
}

provider "aws" {
  region = var.aws_region
}

locals {
  vpc_cidr_block = "10.0.0.0/22"
  azs = data.aws_availability_zones.current.names
}

resource "aws_vpc" "main-learn-vpcs" {
  cidr_block = local.vpc_cidr_block

  tags = {
    Name    = "main-learn-vpcs"
    purpose = "learn vpcs"
  }
}

# it's a good practice to have a subnet per AZ, which is ignored in the tutorial 
# the below is roughly what the tutorial is going to do 
# resource "aws_subnet" "public-learn-vpcs" {
#   vpc_id     = aws_vpc.main-learn-vpcs.id
#   cidr_block = "10.0.0.0/24"
#   availability_zone = local.azs[0]

#   tags = {
#     Name = "public-learn-vpcs"
#   }
# }

# hence as usual I'm going for the more advanced example
resource "aws_subnet" "public-learn-vpcs" {
  count = length(local.azs)

  vpc_id = aws_vpc.main-learn-vpcs.id
  # local.vpc_cidr_block is the parent address space
  # 2 corresponds to /24, 3 to /25, etc - because the parent cidr is /22 => 22 + 2 = 24
  # count.index should be self-explanatory
  cidr_block        = cidrsubnet(local.vpc_cidr_block, 2, count.index)
  availability_zone = local.azs[count.index]

  # gets only the letter of the AZ, i.e. a, b, c, d, etc.
  tags = {
    Name = "public-${substr(local.azs[count.index], -1, 1)}-learn-vpcs"
  }
}
