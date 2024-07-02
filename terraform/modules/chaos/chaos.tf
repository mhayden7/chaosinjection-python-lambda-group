resource "aws_lambda_layer_version" "chaos_layer_python_max_3_11" {
    for_each = toset(var.python_versions_max_3_11)

    layer_name = "${var.config.project}_${local.module}_${replace(each.value, ".", "_")}"
    compatible_runtimes = ["${each.value}"]
    filename = "../chaoslayerpython.zip"
    # source_code_hash = filebase64sha256("../chaoslayerpython.zip")
}

resource "aws_lambda_layer_version" "chaos_layer_python_max_3_12" {
    for_each = toset(var.python_versions_max_3_12)

    layer_name = "${var.config.project}_${local.module}_${replace(each.value, ".", "_")}"
    compatible_runtimes = ["${each.value}"]
    filename = "../chaoslayerpython.zip"
    # source_code_hash = filebase64sha256("../chaoslayerpython.zip")
}

resource "aws_ssm_document" "inject_chaos_document" {
    name = "InjectChaosForPythonLambdaGroups"
    document_type = "Automation"
    document_format = "YAML"

    content = <<DOC
schemaVersion: '0.3'
assumeRole: ${aws_iam_role.chaos_assume_role.arn}
description: Inject chaos into a list of python lambdas.
parameters:
    LambdaList:
        type: StringList
        description: LambdaList
mainSteps:
    - name: RunInjectionScript
      action: aws:executeScript
      inputs:
        Runtime: python3.11
        Handler: handler
        InputPayload:
            LambdaList: "{{LambdaList}}"
        Script: |-
            import boto3
            import json

            def handler(event, context):
                lambdas = event['LambdaList']
            # if 1 == 1:
            #     lambdas = ['helloworld_3_9']
                print(lambdas)
                lambda_client = boto3.client('lambda')
                ssm_client = boto3.client('ssm')
                iam_client = boto3.client('iam')
                injected_access_policy_arn = ssm_client.get_parameter(Name='ChaosLambdaInjections-access_policy')['Parameter']['Value']
                layers = lambda_client.list_layers()

                for l in lambdas:
                    # Backup the config
                    lambda_config = lambda_client.get_function_configuration(FunctionName=l)
                    ssm_client.put_parameter(Name=f"/ChaosLambdaInjections/lambda/{lambda_config['FunctionName']}", 
                                            Value=json.dumps(lambda_config), 
                                            Type='String', 
                                            Overwrite=False)

                    # Find correct chaos layer to inject
                    lambda_layers = [layer['Arn'] for layer in lambda_config['Layers']]
                    for layer in layers['Layers']:
                        if 'python-lambda-chaos-injection' in layer['LayerName'] and lambda_config['Runtime'] in layer['LatestMatchingVersion']['CompatibleRuntimes']:
                            lambda_layers.append(layer['LatestMatchingVersion']['LayerVersionArn'])
                            # layer_arn = layer['LatestMatchingVersion']['LayerVersionArn']
                            handler = f"{lambda_config['Runtime'].replace('.', '_')}.chaos_handler"

                    # Inject!
                    lambda_client.update_function_configuration(FunctionName=l, Layers=lambda_layers, Timeout=300, Handler=handler)

                    # Add required access policy to injected lambda
                    lambda_role = lambda_config['Role'].split(':')[-1].replace('role/', '')
                    print(lambda_role, injected_access_policy_arn)
                    iam_client.attach_role_policy(
                        RoleName=lambda_role,
                        PolicyArn=injected_access_policy_arn
                    )
DOC
}

resource "aws_ssm_document" "rollback_chaos_document" {
    name = "RollbackChaosForPythonLambdaGroups"
    document_type = "Automation"
    document_format = "YAML"

    content = <<DOC
schemaVersion: '0.3'
assumeRole: ${aws_iam_role.chaos_assume_role.arn}
description: Rollback chaos injected into a list of python lambdas.
mainSteps:
    - name: RunInjectionScript
      action: aws:executeScript
      inputs:
        Runtime: python3.11
        Handler: handler
        Script: |-
          import boto3
          import json

          def handler(event, context):
              ssm_client = boto3.client('ssm')
              paginator = ssm_client.get_paginator('get_parameters_by_path')
              response_iterator = paginator.paginate(Path="/ChaosLambdaInjections/lambda")
              parameters = []
              for page in response_iterator:
                  for entry in page['Parameters']:
                      parameters.append(json.loads(entry['Value']))

              lambda_client = boto3.client('lambda')
              iam_client = boto3.client('iam')
              injected_access_policy_arn = ssm_client.get_parameter(Name='ChaosLambdaInjections-access_policy')['Parameter']['Value']

              for config in parameters:
                  function_name = config["FunctionName"]
                  handler = config["Handler"]
                  timeout = config['Timeout']
                  layers = [layer['Arn'] for layer in config['Layers']]
                  lambda_client.update_function_configuration(FunctionName=function_name, Layers=layers, Timeout=timeout, Handler=handler)

                  lambda_role = config['Role'].split(':')[-1].replace('role/', '')
                  policies = iam_client.list_attached_role_policies(RoleName=lambda_role)
                  for policy in policies['AttachedPolicies']:
                      if policy['PolicyName'] == injected_access_policy_arn:
                          iam_client.detach_role_policy(
                              RoleName=lambda_role,
                              PolicyArn=injected_access_policy_arn
                          )

                  ssm_client.delete_parameter(Name=f"/ChaosLambdaInjections/lambda/{function_name}")
DOC
}

resource "aws_fis_experiment_template" "injectchaos" {
  description = "Inject chaos in python-based lambdas with pre-configured chaos injection layers."
  role_arn = aws_iam_role.chaos_fis_assume_role.arn

  stop_condition {
    source = "none"
  }

  action {
    name = "ssm_chaos_injection"
    action_id = "aws:ssm:start-automation-execution"
    parameter {
      key = "documentArn"
      value = aws_ssm_document.inject_chaos_document.arn
    }
    parameter {
      key = "documentParameters"
      value = "{\"LambdaList\":\"Update function list here, i.e. Function1,Function2, etc\"}"
    }
    parameter {
      key = "maxDuration"
      value = "PT1M"
    }
  }
}