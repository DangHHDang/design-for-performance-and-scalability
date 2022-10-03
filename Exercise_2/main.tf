terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 4.16"
        }
    }

    required_version = ">= 1.2.0"
}

# TODO: Designate a cloud provider, region, and credentials
provider "aws" {
  profile = "dangdhh"
  region  = "us-west-2"
}

data "archive_file" "lambda_zip" {
  type = "zip"
  source_file = "greet_lambda.py"
  output_path = var.lambda_output_path
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_logs_policy" {
  name = "lambda_logs_policy"
  path = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*",
        "Effect" : "Allow"
    }]
  })
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 14
}

resource "aws_iam_role_policy_attachment" "lambda_logs_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}


resource "aws_lambda_function" "geeting_lambda" {
  function_name = var.lambda_name
  filename = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler = "greet_lambda.lambda_handler"
  runtime = "python3.8"
  role = aws_iam_role.lambda_exec_role.arn

  environment {
    variables = {
        greeting = "Hello World!"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs_policy,
    aws_cloudwatch_log_group.lambda_log_group
  ]
}