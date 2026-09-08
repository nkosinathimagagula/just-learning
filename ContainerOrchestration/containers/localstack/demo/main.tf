terraform {
  required_providers {
    aws           = { source  = "hashicorp/aws" }
    archive       = { source  = "hashicorp/archive" }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    dynamodb = "http://localhost:4566"
    iam       = "http://localhost:4566"
    lambda    = "http://localhost:4566"
    sts       = "http://localhost:4566"
  }
}

resource "aws_dynamodb_table" "messages" {
  name            = "Messages"
  billing_mode    = "PAY_PER_REQUEST"
  hash_key        = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/dist/handler.zip"
  source_dir  = "${path.module}/dist"
}

resource "aws_iam_role" "lambda_role" {
  name                    = "lambda_role"
  assume_role_policy      = jsonencode({
    Version     = "2012-10-17"
    Statement   = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service   = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_lambda_function" "message_api" {
  function_name       = "message_api"
  role                = aws_iam_role.lambda_role.arn
  handler             = "handler.handler"
  runtime             = "nodejs20.x"
  filename            = data.archive_file.lambda.output_path
  source_code_hash    = data.archive_file.lambda.output_base64sha256
  environment {
    variables = {
      TABLE_NAME         = aws_dynamodb_table.messages.name
      DYNAMODB_ENDPOINT  = "http://host.docker.internal:4566"
    }
  }
}

resource "aws_lambda_function_url" "message_api" {
  function_name       = aws_lambda_function.message_api.function_name
  authorization_type  = "NONE"
}

output "function_url" {
  value = aws_lambda_function_url.message_api.function_url
}
