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

# resource "aws_default_subnet" "default_az1" {
#   availability_zone = "us-west-2a"

#   tags = {
#     Name = "Default subnet for us-west-2a"
#   }
# }
