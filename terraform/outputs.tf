output "public_ip" {
  description = "Elastic IP address of the production VM."
  value       = module.infra.public_ip
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = module.infra.instance_id
}

output "data_volume_id" {
  description = "EBS volume ID mounted for the Postgres data directory."
  value       = module.infra.data_volume_id
}
