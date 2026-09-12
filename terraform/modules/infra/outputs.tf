output "public_ip" {
  description = "Elastic IP address."
  value       = aws_eip.main.public_ip
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.main.id
}

output "data_volume_id" {
  description = "EBS data volume ID."
  value       = aws_ebs_volume.data.id
}

output "vpc_id" {
  description = "VPC ID shared by all a2t-mrv resources."
  value       = aws_vpc.main.id
}

output "db_subnet_ids" {
  description = "Private subnet IDs for the RDS DB subnet group (two AZs)."
  value       = [aws_subnet.db_a.id, aws_subnet.db_b.id]
}

output "app_security_group_id" {
  description = "Security group ID of the EC2 app instance (used for RDS ingress rule)."
  value       = aws_security_group.main.id
}
