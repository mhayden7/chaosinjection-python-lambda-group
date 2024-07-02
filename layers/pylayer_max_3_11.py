import imp
import json
import boto3
import os
import random
import time
import sys

def chaos_handler(event, context):
    # inject delay between 100-3000 ms     
    inject_delay()
    
    function_name  = os.environ['AWS_LAMBDA_FUNCTION_NAME']
    #get parameters
    ssm = boto3.client('ssm')
    stored_config_parameter = f"/ChaosLambdaInjections/lambda/{function_name}"
    print(f"Using stored config parameter {stored_config_parameter}")
    function_config = json.loads(ssm.get_parameter(Name=stored_config_parameter)['Parameter']['Value'])
    filename, handler = function_config['Handler'].split('.')    
    
    # find and invoke the old handler 
    file = None
    try:
        file, pathname, description = imp.find_module(filename) 
        module = imp.load_module(filename ,file , pathname, description)
        old_handler = getattr(module, handler)
        return old_handler(event, context)
    finally:
        if file is not None:
            file.close()
    
def inject_delay():
    random_delay = random.randint(1000, 3000)
    if random_delay % 4 == 0:
        sys.exit('Chaos injected failure')
    else:
        print ('Injecting delay for ' + str(random_delay) + ' ms' )
        time.sleep(random_delay/1000)
    
    