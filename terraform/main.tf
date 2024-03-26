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
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}


# ---------------Lambda IAM role------------------------------

resource "aws_iam_role" "lambda_role" {
  name               = "exam-scribe-lambda-role"
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
  name   = "exam-scribe-lambda-dynamodb-policy"
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
          "dynamodb:Query"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.my_dynamodb_table.arn
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
          "s3:GetObject",
          "s3:PutObject",
        ],
        Effect = "Allow",
        Resource = aws_s3_bucket.exam_scribe_bucket.arn
      }]
  })
}

resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
   for_each = toset([
    aws_iam_policy.lambda_function_logging_policy.arn,
    aws_iam_policy.lambda_dynamodb_policy.arn,
    aws_iam_policy.lambda_s3_policy.arn,
  ])
  role       = aws_iam_role.lambda_role.id
  policy_arn = each.value

  depends_on = [
    aws_iam_policy.lambda_function_logging_policy,
    aws_iam_policy.lambda_dynamodb_policy,
    aws_iam_policy.lambda_s3_policy,
  ]
}

# ---------------Web access IAM user------------------------------
resource "aws_iam_user" "exam_scribe_user" {
  name = "exam_scribe_user"
}

resource "aws_iam_access_key" "exam_scribe_key" {
  user = aws_iam_user.exam_scribe_user.name
}

resource "aws_iam_user_policy" "exam_scribe_user_s3_policy" {
  name = "exam_scribe_user_s3_policy"
  user = aws_iam_user.exam_scribe_user.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        Resource = aws_s3_bucket.exam_scribe_bucket.arn
      }
    ]
  })
}

resource "local_sensitive_file" "access_keys" {
  content  = "REACT_APP_AWS_ACCESS_KEY_ID=${aws_iam_access_key.exam_scribe_key.id}\nREACT_APP_AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.exam_scribe_key.secret}"
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

  source_file = var.path_source_code
  output_path = var.output_path
  type        = "zip"
}

data "archive_file" "create_layer_pkg"{
  source_dir = var.path_layer_source
  output_path = var.layer_output_path
  type = "zip"
}

# ---------------LAMBDA---------------------------

# Create the Lambda function
resource "aws_lambda_function" "exam_scribe_lambda_function" {
  filename         = data.archive_file.create_dist_pkg.output_path
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = data.archive_file.create_dist_pkg.output_base64sha256
  handler          = "pdf_processing.lambda_handler" # assuming your entry point is lambda_handler
  runtime          = var.runtime # specify your Python runtime version
  layers = [aws_lambda_layer_version.pymupdf_layer.arn]
}

resource "aws_lambda_layer_version" "pymupdf_layer" {
  layer_name = "pymupdf"
  description = "pdf parser package"
  filename = var.layer_output_path
  compatible_runtimes = ["python3.12"]
}

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

resource "aws_dynamodb_table" "my_dynamodb_table" {
  name           = "ExamScribeDB"
  billing_mode   = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "BookTitle"

  attribute {
    name = "BookTitle"
    type = "S"
  }

  tags = {
    Name        = "ExamScribeDB"
    Environment = "production"
  }
}

