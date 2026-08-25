# Verifies internal wiring of the infra module without any real AWS calls.
# Requires Terraform >= 1.11.0 (override_during support).

mock_provider "aws" {}

variables {
  aws_region          = "eu-west-1"
  instance_type       = "t3.small"
  key_name            = "test-key"
  ssh_cidr_blocks     = ["10.0.0.0/8"]
  data_volume_size_gb = 50
  tags                = { Environment = "test" }
}

run "security_group_has_three_ingress_rules" {
  command = plan

  assert {
    condition     = length(aws_security_group.main.ingress) == 3
    error_message = "Security group must have exactly 3 ingress rules (SSH, HTTP, HTTPS)"
  }
}

run "security_group_allows_ssh_22" {
  command = plan

  assert {
    condition = anytrue([
      for rule in aws_security_group.main.ingress : rule.from_port == 22 && rule.to_port == 22 && rule.protocol == "tcp"
    ])
    error_message = "Security group must allow TCP port 22 (SSH)"
  }
}

run "security_group_allows_http_80" {
  command = plan

  assert {
    condition = anytrue([
      for rule in aws_security_group.main.ingress : rule.from_port == 80 && rule.to_port == 80 && rule.protocol == "tcp"
    ])
    error_message = "Security group must allow TCP port 80 (HTTP)"
  }
}

run "security_group_allows_https_443" {
  command = plan

  assert {
    condition = anytrue([
      for rule in aws_security_group.main.ingress : rule.from_port == 443 && rule.to_port == 443 && rule.protocol == "tcp"
    ])
    error_message = "Security group must allow TCP port 443 (HTTPS)"
  }
}

run "ebs_volume_size_matches_var" {
  command = plan

  assert {
    condition     = aws_ebs_volume.data.size == var.data_volume_size_gb
    error_message = "EBS data volume size must match var.data_volume_size_gb"
  }
}

run "ebs_volume_az_matches_instance" {
  command = plan

  override_resource {
    target          = aws_instance.main
    override_during = plan
    values = {
      availability_zone = "eu-west-1a"
    }
  }

  assert {
    condition     = aws_ebs_volume.data.availability_zone == aws_instance.main.availability_zone
    error_message = "EBS data volume availability_zone must match the instance's availability_zone"
  }
}

run "eip_bound_to_instance" {
  command = plan

  override_resource {
    target          = aws_instance.main
    override_during = plan
    values = {
      id = "i-0123456789abcdef0"
    }
  }

  assert {
    condition     = aws_eip.main.instance == aws_instance.main.id
    error_message = "Elastic IP must be bound to aws_instance.main"
  }
}
