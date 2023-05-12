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
