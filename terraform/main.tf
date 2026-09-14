data "aws_caller_identity" "current" {}

# ── Runtime SSM Parameters ────────────────────────────────────────────────────
# Written at terraform apply time; read by scripts/deploy/after_install.sh at
# every CodeDeploy deployment. Decouples deploy scripts from hardcoded ARNs.
resource "aws_ssm_parameter" "db_secret_arn" {
  name  = "/a2t-mrv/deploy/db-secret-arn"
  type  = "String"
  value = module.rds.db_secret_arn
}

resource "aws_ssm_parameter" "cognito_pool_id" {
  name  = "/a2t-mrv/runtime/cognito-user-pool-id"
  type  = "String"
  value = module.cognito.user_pool_id
}

resource "aws_ssm_parameter" "cognito_domain_prefix" {
  name  = "/a2t-mrv/runtime/cognito-domain-prefix"
  type  = "String"
  value = var.cognito_domain_prefix
}

resource "aws_ssm_parameter" "phx_host" {
  name  = "/a2t-mrv/runtime/phx-host"
  type  = "String"
  value = module.infra.public_ip
}

locals {
  storage_bucket_name = "a2t-mrv-storage-${data.aws_caller_identity.current.account_id}"
}

module "infra" {
  source = "./modules/infra"

  instance_type       = var.instance_type
  key_name            = var.key_name
  ssh_cidr_blocks     = var.ssh_cidr_blocks
  data_volume_size_gb = var.data_volume_size_gb
  tags                = var.tags

  db_secret_arn              = module.rds.db_secret_arn
  secret_key_base_secret_arn = module.rds.secret_key_base_secret_arn
  cognito_client_secret_arn  = module.cognito.client_secret_arn
  storage_bucket_name        = local.storage_bucket_name
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

module "storage" {
  source = "./modules/storage"

  bucket_name           = local.storage_bucket_name
  ec2_instance_role_arn = module.infra.instance_role_arn
  create_bucket_policy  = true
  days_to_warm          = var.storage_days_to_warm
  days_to_cold          = var.storage_days_to_cold
  tags                  = var.tags
}
