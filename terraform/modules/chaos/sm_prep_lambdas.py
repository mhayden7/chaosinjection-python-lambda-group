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