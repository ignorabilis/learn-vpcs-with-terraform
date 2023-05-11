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
  all_subnets           = concat(aws_route_table.private-learn-vpcs, [aws_route_table.public-learn-vpcs])
}

resource "aws_vpc" "main-learn-vpcs" {
  cidr_block = local.vpc_cidr_block
  enable_dns_hostnames = true

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

  route {
    # all traffic obv
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-learn-vpcs.id
  }

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

# because cidr blocks have to be unique in a route table I need to pick up
# each subnet and using the subnet_id associated with each nat gateway 
# to find the subnet cidr
# OK, this is not true - the traffic is actually egress so the cidr_block
# should probably be different; and then the subnet_id of a nat gw is the
# one in which the nat gw is placed (so the public one), not the one 
# associated with (so the private)
# keeping the whole thing just for reference 
#
# dynamic "route" {
#   for_each = toset(values(aws_nat_gateway.nat-gw))
#   content {
#     cidr_block = { for idx, name in aws_subnet.private-learn-vpcs : name.id => name }[route.value.subnet_id].cidr_block
#     # remember - `each` cannot be used because that would clash
#     # with a resource `each`; so the name of the dynamic block is used instead
#     nat_gateway_id = route.value.id
#   }
# }

resource "aws_route_table" "private-learn-vpcs" {
  # the only way I found is by creating a route table per nat-gw
  # confirmed by chatgpt4...
  # searched aws' docs but could not confirm
  # currently there's a nat in each public subnet, but we only care about nats;
  # if the are more public subnets for some reason we should not care
  count = length(aws_nat_gateway.nat-gw)

  vpc_id = aws_vpc.main-learn-vpcs.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw[count.index].id
  }

  tags = {
    Name = "private-${substr(local.azs[count.index], -1, 1)}-learn-vpcs"
  }
}

resource "aws_route_table_association" "priv" {
  # here we're concerned with the private subnets instead; if there are more
  # private subnets for some reason we should just associate those with the
  # existing route tables
  count = local.public_subnets_count

  subnet_id      = aws_subnet.private-learn-vpcs[count.index].id
  route_table_id = aws_route_table.private-learn-vpcs[count.index % length(aws_nat_gateway.nat-gw)].id
}

resource "aws_internet_gateway" "igw-learn-vpcs" {
  # prefer using the aws_internet_gateway_attachment resource
  #vpc_id = aws_vpc.main-learn-vpcs.id

  tags = {
    Name = "igw-learn-vpcs"
  }
}

# should be clearer and more maintainable compared to giving the vpc id directly
resource "aws_internet_gateway_attachment" "igw-learn-vpcs" {
  internet_gateway_id = aws_internet_gateway.igw-learn-vpcs.id
  vpc_id              = aws_vpc.main-learn-vpcs.id
}

resource "aws_eip" "nat_gw_ip" {
  for_each = { for idx, name in aws_subnet.public-learn-vpcs : idx => name }

  # EC2 classic stuff - don't care right now, if I encounter it will research
  vpc = true

  tags = {
    Name = "eip-${substr(each.value.availability_zone, -1, 1)}-learn-vpcs"
  }
}

resource "aws_nat_gateway" "nat-gw" {
  for_each = { for idx, name in aws_subnet.public-learn-vpcs : idx => name }

  subnet_id     = each.value.id
  allocation_id = aws_eip.nat_gw_ip[each.key].id

  tags = {
    Name = "nat-gw-${substr(each.value.availability_zone, -1, 1)}-learn-vpcs"
  }
}

resource "aws_s3_bucket" "ignorabilis-learn-aws-bucket" {
  bucket = "ignorabilis-learn-aws-bucket"
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.main-learn-vpcs.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  # cheaper option, supported by S3 for example but not supported by everything
  # for more advanced stuff Interface needs to be used
  vpc_endpoint_type = "Gateway"
  # can be true only if the type is Interface (not sure about GatewayLoadBalancer)
  #private_dns_enabled = true

  route_table_ids = [for rt in local.all_subnets : rt.id]
}

# Create a policy to allow access to the S3 bucket from the VPC endpoint
data "aws_iam_policy_document" "ignorabilis-learn-aws-bucket-policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.ignorabilis-learn-aws-bucket.arn,
      "${aws_s3_bucket.ignorabilis-learn-aws-bucket.arn}/*",
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:sourceVpce"
      values   = [aws_vpc_endpoint.s3_endpoint.id]
    }
  }
}

resource "aws_s3_bucket_policy" "ignorabilis-learn-aws-bucket-policy" {
  bucket = aws_s3_bucket.ignorabilis-learn-aws-bucket.id
  policy = data.aws_iam_policy_document.ignorabilis-learn-aws-bucket-policy.json
}
