#!/bin/bash
# if needed, make executable with chmod u+x publish.sh
project_dir=$(pwd)

echo "Bundle Python Chaos Layer code"
echo $'#########################################\n'
rm -f *.zip
cd ./layers/
mkdir python
cp pylayer_max_3_11.py ./python/python3_8.py
cp pylayer_max_3_11.py ./python/python3_9.py
cp pylayer_max_3_11.py ./python/python3_10.py
cp pylayer_max_3_11.py ./python/python3_11.py
cp pylayer_max_3_12.py ./python/python3_12.py
zip -qr "$project_dir/chaoslayerpython.zip" python
rm -rf python
cd $project_dir

echo "Bundle Example Lambda code"
echo $'#########################################\n'
cd ./lambdaFunctions/python/
zip -qr "$project_dir/examplelambdas.zip" lambda_function.py
cd $project_dir

echo "Publish Terraform"
echo $'#########################################\n'
cd ./terraform
terraform init
terraform apply
cd $project_dir