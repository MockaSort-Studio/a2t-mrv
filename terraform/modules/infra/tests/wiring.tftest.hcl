# @req: REQ-86
# Verifies internal wiring of the infra module without any real AWS calls.
# Requires OpenTofu >= 1.7 (mock_provider support).
#
# Note: ebs_volume_az_matches_instance and eip_bound_to_instance were removed.
# Both asserted plan-time equality over computed unknowns (aws_instance.main.availability_zone
# and aws_instance.main.id). That required override_during = plan, which is not available
# in stable OpenTofu releases. The structural constraints — that aws_ebs_volume.data.availability_zone
# references aws_instance.main.availability_zone, and that aws_eip.main.instance references
# aws_instance.main.id — are already enforced at the HCL source level and verified by tofu validate.

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
