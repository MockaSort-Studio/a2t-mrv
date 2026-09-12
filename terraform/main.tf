module "infra" {
  source = "./modules/infra"

  instance_type       = var.instance_type
  key_name            = var.key_name
  ssh_cidr_blocks     = var.ssh_cidr_blocks
  data_volume_size_gb = var.data_volume_size_gb
  tags                = var.tags
}

module "rds" {
  source = "./modules/rds"

  vpc_id                = module.infra.vpc_id
  db_subnet_ids         = module.infra.db_subnet_ids
  app_security_group_id = module.infra.app_security_group_id

  db_name               = var.db_name
  db_username           = var.db_username
  backup_retention_days = var.backup_retention_days
  tags                  = var.tags
}

module "cognito" {
  source = "./modules/cognito"

  app_name      = var.cognito_app_name
  domain_prefix = var.cognito_domain_prefix
  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls
  tags          = var.tags
}
