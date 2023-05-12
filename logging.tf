# this (and other pieces) can technically be a separate module
# for the sake of speed though keeping things simple 
# (or maybe I'm just lazy)
resource "aws_cloudwatch_log_group" "learn_vpcs_flow_logs" {
  name              = "learn_vpcs_flow_logs"
  retention_in_days = 7

  tags = {
    "Name" = "learn_vpcs_flow_logs"
  }

  # can be potentially like this (if it was a module with vars, etc.)
  #   tags = merge(
  #     { "Name" = var.name },
  #     var.tags,
  #     var.log_group_tags,
  #   )
}

data "aws_iam_policy_document" "assume_role_vpc_flow_logs" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "learn_vpcs_vpc_flow_logs" {
  name               = "learn_vpcs_vpc_flow_logs"
  assume_role_policy = data.aws_iam_policy_document.assume_role_vpc_flow_logs.json
}

data "aws_iam_policy_document" "permissions_vpc_flow_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "permissions_vpc_flow_logs" {
  name   = "permissions_vpc_flow_logs"
  role   = aws_iam_role.learn_vpcs_vpc_flow_logs.id
  policy = data.aws_iam_policy_document.permissions_vpc_flow_logs.json
}

resource "aws_flow_log" "learn_vpcs_flow_log" {
  vpc_id          = aws_vpc.main-learn-vpcs.id
  iam_role_arn    = aws_iam_role.learn_vpcs_vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.learn_vpcs_flow_logs.arn
  traffic_type    = "ALL"
}
