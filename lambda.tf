resource "aws_lambda_function" "scale" {
  count = var.region == "secondary" ? 1 : 0
  
  runtime       = "python3.12"
  function_name = "scale-ecs"
  handler       = "index.handler"
  filename      = "lambda_function.zip"
  role          = aws_iam_role.Lambda_Role.arn
  environment {
    variables = {
      CLUSTER_ARN = aws_ecs_cluster.CloudOpsBlend.arn
    }
  }
}

resource "aws_iam_role" "Lambda_Role" {
  name = "Lambda_Role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          Service : "lambda.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "Log_Group" {
  count = var.region == "secondary" ? 1 : 0

  name = "/aws/lambda/${aws_lambda_function.scale[0].function_name}"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "./ecs_disaster_recovery/index.py"
  output_path = "./lambda_function.zip"
}
