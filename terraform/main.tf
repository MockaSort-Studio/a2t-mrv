# @req: REQ-86
module "infra" {
  source = "./modules/infra"

  instance_type       = var.instance_type
  key_name            = var.key_name
  ssh_cidr_blocks     = var.ssh_cidr_blocks
  data_volume_size_gb = var.data_volume_size_gb
  tags                = var.tags
}
