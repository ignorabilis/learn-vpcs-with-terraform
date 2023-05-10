data "aws_region" "current" {}
data "aws_availability_zones" "current" {
  state = "available"
}

provider "aws" {
  region = var.aws_region
}

locals {
  # the example uses /22 but that's unmanageable
  # /22 allows only 4 subnets with /24, but if I want a subnet per AZ
  # and I have public & private subnets this means at least 8 subnets
  # in us-west-2, thus a switch to /21 would be needed; however /21 is not
  # enough if the app "needs to grow" (it won't obv), 
  # so switching to at least /20 is needed and that would provide 16 subnets
  vpc_cidr_block        = "10.0.0.0/20"
  azs                   = data.aws_availability_zones.current.names
  public_subnets_count  = length(local.azs)
  private_subnets_count = length(local.azs)
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

# hence as usual I'm going for the more advanced setup
resource "aws_subnet" "public-learn-vpcs" {
  count = local.public_subnets_count

  vpc_id = aws_vpc.main-learn-vpcs.id
  # local.vpc_cidr_block is the parent address space
  # 2 corresponds to /22, 4 to /24, etc - 
  # because the parent cidr is /20 => 20 + 2 = 22
  # count.index should be self-explanatory
  cidr_block        = cidrsubnet(local.vpc_cidr_block, 4, count.index)
  availability_zone = local.azs[count.index]

  # gets only the letter of the AZ, i.e. a, b, c, d, etc.
  tags = {
    Name = "public-${substr(local.azs[count.index], -1, 1)}-learn-vpcs"
  }
}

# only one route table needed as the subnets are multiple for the availability
resource "aws_route_table" "public-learn-vpcs" {
  vpc_id = aws_vpc.main-learn-vpcs.id

  route = []

  tags = {
    Name = "public-learn-vpcs"
  }
}

resource "aws_route_table_association" "pub" {
  count = local.public_subnets_count

  subnet_id      = aws_subnet.public-learn-vpcs[count.index].id
  route_table_id = aws_route_table.public-learn-vpcs.id
}

# private subnets
resource "aws_subnet" "private-learn-vpcs" {
  count = local.private_subnets_count

  vpc_id = aws_vpc.main-learn-vpcs.id
  # 1 corresponds to /21 and 4 to /24 - see the public subnets 
  # and the example is using it with the intention to have more addresses
  # for the private subnets
  # the issue is that the whole vpc was /22, thus adding 1 new bit would allow me
  # to have only 2 subnets;
  # the region has 4 AZs so changing the private ones too is needed
  # NOTE - private subnets start after the public subnets
  cidr_block        = cidrsubnet(local.vpc_cidr_block, 4, local.public_subnets_count + count.index)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "private-${substr(local.azs[count.index], -1, 1)}-learn-vpcs"
  }
}

resource "aws_route_table" "private-learn-vpcs" {
  vpc_id = aws_vpc.main-learn-vpcs.id

  route = []

  tags = {
    Name = "private-learn-vpcs"
  }
}

resource "aws_route_table_association" "priv" {
  count = local.public_subnets_count

  subnet_id      = aws_subnet.private-learn-vpcs[count.index].id
  route_table_id = aws_route_table.private-learn-vpcs.id
}
