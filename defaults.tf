# importing is needed, otherwise TF attempts to create it
# for reference:
# terraform import aws_default_vpc.default vpc-d327a3ab
resource "aws_default_vpc" "default" {
  tags = {
    Name = "DO_NOT_USE_OR_DELETE_DEFAULT_TF"
  }

  # it's optional and false by default - but just to make sure it's here
  force_destroy = false
}

# again, importing is needed
# for reference:
# terraform import aws_default_subnet.default[0] subnet-d39889aa
# terraform import aws_default_subnet.default[1] subnet-db261490
# terraform import aws_default_subnet.default[2] subnet-37ac4f6a
# terraform import aws_default_subnet.default[3] subnet-7bad3650
resource "aws_default_subnet" "default" {
  count = length(local.azs)

  # vpc_id is computed
  availability_zone = local.azs[count.index]

  # keep it to avoid changes, the default subnets have it... by default...
  # did I say default? 
  timeouts {}

  tags = {
    Name = "${substr(local.azs[count.index], -1, 1)}_DO_NOT_USE_OR_DELETE_DEFAULT_TF"
  }

  # it's optional and false by default - but just to make sure it's here
  force_destroy = false
}
