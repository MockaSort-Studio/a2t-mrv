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
