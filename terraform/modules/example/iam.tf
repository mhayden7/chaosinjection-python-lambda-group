data "aws_iam_policy_document" "lambda_sts_assume_role" {
    statement {
      effect = "Allow"
      principals {
        type = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }
      actions = ["sts:AssumeRole"]
    }
}

data "aws_iam_policy_document" "lambda_logging" {
    statement {
      effect = "Allow"
      actions = ["logs:CreateLogGroup"]
      resources = ["arn:aws:logs:${var.config.region}:${var.config.account}:log-group:/aws/lambda/${var.config.project}_${local.module}*"]
    }
    statement {
      effect = "Allow"
      actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
      resources = ["arn:aws:logs:${var.config.region}:${var.config.account}:log-group:/aws/lambda/${var.config.project}_${local.module}*"]
    }
}

resource "aws_iam_policy" "lambda-logging-policy" {
  name = "lambda-logging-${var.config.project}"
  policy = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_role" "lambda-execution-role" {
  name = "${var.config.project}_${local.module}_lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_sts_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda-logging-policy" {
  role = aws_iam_role.lambda-execution-role.name
  policy_arn = aws_iam_policy.lambda-logging-policy.arn
}