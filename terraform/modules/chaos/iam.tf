# ----------------------------------------------------------------
# Execution role for SSM
# ----------------------------------------------------------------
  data "aws_iam_policy_document" "sts_assume_role" {
    statement {
      effect = "Allow"
      principals {
        type = "Service"
        identifiers = ["ssm.amazonaws.com"]
      }
      actions = ["sts:AssumeRole"]
    }
  }

  resource "aws_iam_role" "chaos_assume_role" {
    name = "${var.config.project}_${local.module}_role"
    assume_role_policy = data.aws_iam_policy_document.sts_assume_role.json
  }

  data "aws_iam_policy_document" "chaos_injection_policy_data" {
    # manipulate lambdas
    statement {
      effect = "Allow"
      actions = ["lambda:UpdateFunctionConfiguration", 
                 "lambda:GetFunctionConfiguration", 
                 "lambda:GetFunction", 
                 "lambda:GetLayerVersion", 
                 "lambda:ListLayers"]
      resources = ["*"]
    }
    statement {
      effect = "Allow"
      actions = ["ssm:PutParameter",
                 "ssm:LabelParameterVersion",
                 "ssm:DescribeDocumentParameters",
                 "ssm:GetParameters",
                 "ssm:GetParameter",
                 "ssm:DescribeParameters",
                 "ssm:GetParametersByPath",
                 "ssm:DeleteParameter"]
      resources = ["arn:aws:ssm:${var.config.region}:${var.config.account}:parameter/ChaosLambdaInjections*"]
    }
    statement {
      effect = "Allow"
      actions = ["iam:AttachrolePolicy",
                 "iam:DetachRolePolicy",
                 "iam:ListAttachedRolePolicies"]
      resources = ["*"]
    } 
  }

  resource "aws_iam_policy" "chaos_injection_policy" {
    name = "${var.config.project}_${local.module}_policy"
    policy = data.aws_iam_policy_document.chaos_injection_policy_data.json
  }

  resource "aws_iam_role_policy_attachment" "choas_injection_role_policy_attachement" {
    role = aws_iam_role.chaos_assume_role.name
    policy_arn = aws_iam_policy.chaos_injection_policy.arn
  }

  
# ----------------------------------------------------------------
# Ensure injected lambdas have access to the Parameter Store
# ----------------------------------------------------------------
  data "aws_iam_policy_document" "chaos_injected_access_requirements" {
    # manipulate lambdas
    statement {
      effect = "Allow"
      actions = ["ssm:GetParameters",
                 "ssm:GetParameter",
                 "ssm:DescribeParameters"]
      resources = ["arn:aws:ssm:${var.config.region}:${var.config.account}:parameter/ChaosLambdaInjections*"]
    }
  }

  resource "aws_iam_policy" "chaos_injected_access_requirements" {
    name = "${var.config.project}_${local.module}_injected_access"
    policy = data.aws_iam_policy_document.chaos_injected_access_requirements.json
  }

  resource "aws_ssm_parameter" "chaos_access_policy_lookup" {
    name = "ChaosLambdaInjections-access_policy"
    type = "String"
    value = aws_iam_policy.chaos_injected_access_requirements.arn
  }

# ----------------------------------------------------------------
# Execution role for FIS
# ----------------------------------------------------------------
  data "aws_iam_policy_document" "fis_assume_role" {
    statement {
      effect = "Allow"
      principals {
        type = "Service"
        identifiers = ["fis.amazonaws.com"]
      }
      actions = ["sts:AssumeRole"]
    }
  }

  resource "aws_iam_role" "chaos_fis_assume_role" {
    name = "${var.config.project}_${local.module}_fis_role"
    assume_role_policy = data.aws_iam_policy_document.fis_assume_role.json
  }

  data "aws_iam_policy_document" "chaos_fis_policy_data" {
    # manipulate lambdas
    statement {
      effect = "Allow"
      actions = ["iam:PassRole"]
      resources = ["arn:aws:iam::*:role/*"]
    }
    statement {
      effect = "Allow"
      actions = ["ssm:StartAutomationExecution"]
      resources = ["arn:aws:ssm:*:*:automation-definition/*:*"]
    }
    statement {
      effect = "Allow"
      actions = ["ssm:GetAutomationExecution", "ssm:StopAutomationExecution"]
      resources = ["arn:aws:ssm:*:*:automation-execution/*"]
    }
  }

  resource "aws_iam_policy" "chaos_fis_policy" {
    name = "${var.config.project}_${local.module}_fis_policy"
    policy = data.aws_iam_policy_document.chaos_fis_policy_data.json
  }

  resource "aws_iam_role_policy_attachment" "choas_fis_role_policy_attachement" {
    role = aws_iam_role.chaos_fis_assume_role.name
    policy_arn = aws_iam_policy.chaos_fis_policy.arn
  }