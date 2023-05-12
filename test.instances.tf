# easiest way to hop on one of those instances
# aws ssm start-session --target i-<ec2-instance-id>

# in case they are running docker and we're interested in a specific container:
# sudo su
# docker exec -it <container-name> bash

data "aws_ami" "ubuntu_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"] # Filter by Ubuntu Jammy 22.04
    # and the world sees a sudden surge of Ubuntu 20.04 usage just because 
    # ChatGPT does not have knowledge of Ubuntu 22.04... ¯\_(ツ)_/¯
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "ubuntu_access" {
  name        = "ubuntu_access"
  description = "Allow SSH access (for now)"
  vpc_id      = aws_vpc.main-learn-vpcs.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # obvs only for testing purposes - going to use it to ping the ip only
  # ICMP is used for network troubleshooting and tasks (typically)
  # NOTE - couldn't ping the instances...
  ingress {
    # this one seems to just enable all traffic...
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    # all ports
    from_port = 0
    to_port   = 0
    # all protocols
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow ICMP traffic from any source
  }

  tags = {
    Name = "Ubuntu Access"
  }
}

resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = ""
        Effect : "Allow"
        Action : "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  # Attach the AmazonSSMManagedInstanceCore policy
  inline_policy {
    name = "ec2_ssm_role_policy"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Sid    = "AllowSSMManagedInstanceCore"
          Effect = "Allow"
          Action = [
            "ssm:UpdateInstanceInformation",
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel"
          ],
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_iam_instance_profile" "ec2_inst_profile_ssm_role" {
  name = "ec2_inst_profile_ssm_role"
  role = aws_iam_role.ec2_ssm_role.name
}

resource "aws_instance" "ubuntu_instance" {
  count = 2

  ami                         = data.aws_ami.ubuntu_ami.id
  instance_type               = "t2.nano"
  associate_public_ip_address = true

  # this is not needed, keeping it for reference:
  #   user_data = <<-EOF
  #     #!/bin/bash
  #     snap install amazon-ssm-agent --classic
  #     systemctl start snap.amazon-ssm-agent.amazon-ssm-agent
  #   EOF

  # just put those on a subnet, they are for testing purposes
  subnet_id              = aws_subnet.public-learn-vpcs[0].id
  vpc_security_group_ids = [aws_security_group.ubuntu_access.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_inst_profile_ssm_role.name

  tags = {
    Name = "Ubuntu Instance ${count.index}"
  }
}
