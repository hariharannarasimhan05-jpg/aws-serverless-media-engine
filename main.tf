provider "aws" {
  region     = "ap-south-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
# 1. Random suffix for globally unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 2. S3 Upload Bucket (Corrected the reference to match 'bucket_suffix')
resource "aws_s3_bucket" "upload_bucket" {
  bucket = "hari-media-upload-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# 3. DynamoDB Table (The Database)
resource "aws_dynamodb_table" "image_labels" {
  name         = "HariImageLabels"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ImageID"

  attribute {
    name = "ImageID"
    type = "S"
  }
}

# 4. SNS Topic (The Alert)
resource "aws_sns_topic" "notification" {
  name = "image-processing-alerts"
}

# 5. SNS Subscription (Your Email)
resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = aws_sns_topic.notification.arn
  protocol  = "email"
  endpoint  = "hariharannarasimhan05@gmail.com" # <--- Update this!
}
# 1. The Trust Policy (Allows Lambda to assume this role)
resource "aws_iam_role" "lambda_processor_role" {
  name = "hari_media_processor_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 2. The Permissions Policy (The "Keys" to other services)
resource "aws_iam_role_policy" "lambda_permissions" {
  name = "hari_media_processor_permissions"
  role = aws_iam_role.lambda_processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObject"],
        Resource = "${aws_s3_bucket.upload_bucket.arn}/*"
      },
      {
        Effect = "Allow",
        Action = ["rekognition:DetectLabels"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["dynamodb:PutItem"],
        Resource = aws_dynamodb_table.image_labels.arn
      },
      {
        Effect = "Allow",
        Action = ["sns:Publish"],
        Resource = aws_sns_topic.notification.arn
      }
    ]
  })
}

# Zip the Python code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "process_image.py"
  output_path = "lambda_function_payload.zip"
}

# Create the Lambda Function
resource "aws_lambda_function" "image_processor" {
  filename      = "lambda_function_payload.zip"
  function_name = "HariImageProcessor"
  role          = aws_iam_role.lambda_processor_role.arn
  handler       = "process_image.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.notification.arn
    }
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# Allow S3 to trigger the Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.upload_bucket.arn
}

# The Trigger: Run Lambda when a .jpg is uploaded
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.upload_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
# 8. S3 Bucket for the Dashboard Frontend
resource "aws_s3_bucket" "dashboard_bucket" {
  bucket        = "hari-ai-dashboard-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# 9. CloudFront Distribution (The Global Edge)
resource "aws_cloudfront_distribution" "dashboard_cdn" {
  origin {
    domain_name              = aws_s3_bucket.dashboard_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.dashboard_oac.id
    origin_id                = "S3-Dashboard"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Dashboard"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }
}

# 10. Origin Access Control (The Security Guard)
resource "aws_cloudfront_origin_access_control" "dashboard_oac" {
  name                              = "dashboard_oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Policy to allow CloudFront Access
resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  bucket = aws_s3_bucket.dashboard_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.dashboard_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.dashboard_cdn.arn
          }
        }
      }
    ]
  })
}

# Output the URL for your LinkedIn Post!
output "dashboard_url" {
  value = aws_cloudfront_distribution.dashboard_cdn.domain_name
}