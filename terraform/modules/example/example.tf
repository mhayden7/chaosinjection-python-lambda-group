  resource "aws_lambda_layer_version" "empty_testing_layer" {
    layer_name = "empty_testing_layer"
    compatible_runtimes = var.python_versions
    filename = "../chaoslayerpython.zip"
    # source_code_hash = filebase64sha256("../chaoslayerpython.zip")
}
  
  resource "aws_lambda_function" "example_lambdas" {
    for_each = toset(var.python_versions)

    filename = "../examplelambdas.zip"
    function_name = "${var.config.project}_${local.module}_${replace(each.value, ".", "_")}_example"
    runtime = "${each.value}"
    handler = "lambda_function.lambda_handler"
    role = aws_iam_role.lambda-execution-role.arn
    source_code_hash = filebase64sha256("../examplelambdas.zip")
    layers = [aws_lambda_layer_version.empty_testing_layer.arn]
  }