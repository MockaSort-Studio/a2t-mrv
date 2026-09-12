output "bucket_id" {
  description = "S3 bucket name."
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "ARN of the CRCF retention bucket. Used by the EC2 instance profile in issue-153."
  value       = aws_s3_bucket.main.arn
}

