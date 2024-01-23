##################### S3

resource "aws_s3_bucket" "site" {
  bucket = "mveletronica.com"
  #force_destroy = true

  lifecycle {
    ignore_changes = [
      website, cors_rule
    ]
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_cors_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = []
    max_age_seconds = 0
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:ListBucket",
        Resource  = aws_s3_bucket.site.arn
      },
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.site.arn}/*"
      }
    ]
  })
  depends_on = [
    aws_s3_bucket.site,
    aws_s3_bucket_public_access_block.site,
    aws_s3_bucket_ownership_controls.site
  ]
}
################################################## IAM
resource "aws_iam_user" "service_s3_bucket_access" {
  name = lower("mveletronica_s3_bucket_write_access")
  tags = {
    provisioner = "terraform"
    project     = "External-Site"
  }

  path = "/system/"
}

resource "aws_iam_access_key" "service_s3_bucket_access" {
  user = aws_iam_user.service_s3_bucket_access.name
}

resource "aws_iam_user_policy" "service_s3_bucket_write_access" {
  name = "mveletronica_S3BucketWriteAccessPolicy"
  user = aws_iam_user.service_s3_bucket_access.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
        ],
        Resource = [
          aws_s3_bucket.site.arn,
          "${aws_s3_bucket.site.arn}/*"
        ]
      }
    ]
  })
}

#### OUTPUT
##################################################

output "iam_user_name" {
  description = "AWS IAM User name"
  value       = aws_iam_access_key.service_s3_bucket_access.user
}

#### Versions

terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.57"
    }
  }
}

#### Backend
terraform {
  backend "s3" {
    bucket  = "tf-state-local-teste"
    key     = "mv-site"
    region  = "us-east-1"
    encrypt = true
  }
}
