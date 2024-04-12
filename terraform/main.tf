# -----------------S3---------------------------
resource "aws_s3_bucket" "exam_scribe_bucket" {
  bucket = "exam-scribe-pdf-upload-bucket"
}

resource "aws_s3_bucket_ownership_controls" "exam_scribe_bucket" {
  bucket = aws_s3_bucket.exam_scribe_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "exam_scribe_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.exam_scribe_bucket]

  bucket = aws_s3_bucket.exam_scribe_bucket.id
  acl    = "private"
}

  # Notification to trigger lambda function
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.exam_scribe_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.exam_scribe_lambda_function.arn
    events              = ["s3:ObjectCreated:Put"]
  }
}

resource "aws_s3_bucket_cors_configuration" "exam_scribe_bucket" {
  bucket = aws_s3_bucket.exam_scribe_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "DELETE"]
    allowed_origins = ["*"] # Change to proper URL
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"] # Change to proper URL
  }
}


# ---------------Lambda IAM role------------------------------

resource "aws_iam_role" "lambda_role" {
  name = "exam-scribe-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ],
  })
}

# Allows lambda console to post to cloudwatch
resource "aws_iam_policy" "lambda_function_logging_policy" {
  name = "exam-scribe-function-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# IAM policy to allow interacting with dynamodb
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name = "exam-scribe-lambda-dynamodb-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:DescribeTable"
        ],
        Effect   = "Allow",
        Resource = [aws_dynamodb_table.user_data.arn, aws_dynamodb_table.question_bank.arn]
      },
    ],
  })
}

resource "aws_iam_policy" "lambda_s3_policy" {
  name = "exam-scribe-lambda-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ],
        Effect   = "Allow",
        Resource = aws_s3_bucket.exam_scribe_bucket.arn
    }]
  })
}


resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
  for_each = {
    "cloudwatch_logging" = aws_iam_policy.lambda_function_logging_policy.arn,
    "dynamo"             = aws_iam_policy.lambda_dynamodb_policy.arn,
    "s3"                 = aws_iam_policy.lambda_s3_policy.arn,
  }
  role       = aws_iam_role.lambda_role.id
  policy_arn = each.value
}

# ---------------Web access IAM user------------------------------
resource "aws_iam_user" "exam_scribe_user" {
  name = "exam_scribe_user"
}

resource "aws_iam_user_policy_attachment" "exam_scribe_user_s3_policy" {
  user       = aws_iam_user.exam_scribe_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_access_key" "exam_scribe_key" {
  user = aws_iam_user.exam_scribe_user.name
}

# resource "aws_iam_user_policy" "exam_scribe_user_s3_policy" {
#   name = "exam_scribe_user_s3_policy"
#   user = aws_iam_user.exam_scribe_user.name

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "s3:*"
#           # "s3:PutObject",
#           # "s3:GetObject",
#           # "s3:DeleteObject"
#         ],
#         Resource = aws_s3_bucket.exam_scribe_bucket.arn
#       }
#     ]
#   })
# }

resource "local_sensitive_file" "access_keys" {
  content  = "VITE_APP_AWS_REGION=${var.region}\nVITE_APP_AWS_ACCESS_KEY_ID=${aws_iam_access_key.exam_scribe_key.id}\nVITE_APP_AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.exam_scribe_key.secret}\nVITE_APP_AWS_BUCKET_NAME=${aws_s3_bucket.exam_scribe_bucket.id}"
  filename = "${path.module}/../client/.env"
}
# --------------------CLOUDWATCH----------------------------

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 1
  lifecycle {
    prevent_destroy = false
  }
}

# ------------- Zip .py file --------------------
# Package the Python code into a ZIP file
data "archive_file" "create_dist_pkg" {

  source_dir  = var.path_source_code
  output_path = var.output_path
  type        = "zip"
}

# data "archive_file" "create_layer_pkg" {
#   source_dir  = "${path.module}/${var.path_package_layer_source}"
#   output_path = var.layer_output_path
#   type        = "zip"
# }

# ---------------LAMBDA---------------------------

# Create the Lambda function
resource "aws_lambda_function" "exam_scribe_lambda_function" {
  filename         = data.archive_file.create_dist_pkg.output_path
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = data.archive_file.create_dist_pkg.output_base64sha256
  handler          = "upload_lambda.lambda_handler" # assuming your entry point is lambda_handler
  runtime          = var.runtime                    # specify your Python runtime version
  # layers           = [aws_lambda_layer_version.pymupdf_layer.arn]
  timeout          = 10
}

# resource "aws_lambda_layer_version" "pymupdf_layer" {
#   layer_name          = "pymupdf"
#   description         = "pdf parser package"
#   filename            = var.layer_output_path
#   compatible_runtimes = ["python3.12"]
# }

resource "aws_lambda_function_url" "exam_scribe_lambda_function_url" {
  function_name      = aws_lambda_function.exam_scribe_lambda_function.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.exam_scribe_lambda_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.exam_scribe_bucket.arn
}

# ---------------DYNAMO-DB------------------------

resource "aws_dynamodb_table" "user_data" {
  name         = "UserDataTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "UserID"

  attribute {
    name = "UserID"
    type = "S"
  }

  tags = {
    Name = "UserDataTable"
  }
}

resource "aws_dynamodb_table" "question_bank" {
  name         = "QuestionBankTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "QuizID"


  attribute {
    name = "QuizID"
    type = "S"
  }

}

# ------------------AWS cognito ------------------------------
# resource "aws_cognito_user_pool" "exam_scribe_pool" {
#   name                     = "exam-scribe-pool"
#   auto_verified_attributes = ["email"]
#   password_policy {
#     minimum_length    = 8
#     require_lowercase = true
#     require_uppercase = true
#     require_numbers   = true
#     require_symbols   = false
#   }
# }

# resource "aws_cognito_user_pool_client" "exam_scribe_client" {
#   name          = "exam-scribe-cognito-client"
#   user_pool_id  = aws_cognito_user_pool.exam_scribe_pool.id

# }
