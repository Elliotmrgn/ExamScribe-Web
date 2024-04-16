variable "region" {
  default = "us-east-1" 
}

variable "path_source_code" {
  default = "../lambda/source"
}

variable "lambda_function_name" {
  default = "exam_scribe_lambda_function"
}

variable "runtime" {
  default = "python3.12"
}

variable "output_path" {
  description = "Path to function's deployment package into local filesystem. eg: /path/lambda_function.zip"
  default = "my_deployment_package.zip"
}

variable "layer_source" {
  default = "../lambda/packages/"
}

variable "layer_output_path" {
  default = "lambda_layer.zip"
}


