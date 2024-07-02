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
