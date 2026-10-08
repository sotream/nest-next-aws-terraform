# Test-only root: a module with ephemeral outputs cannot be a root module, so tests plan it through here.
variable "credentials_version" {
  type    = number
  default = 1
}

variable "db_host" {
  type    = string
  default = "db.example.internal"
}

variable "db_generation" {
  type    = string
  default = "db-generation-1"
}

module "secrets" {
  source              = "../.."
  name_prefix         = "nnat-test"
  credentials_version = var.credentials_version
  db_host             = var.db_host
  db_generation       = var.db_generation
  redis_host          = "redis.example.internal"
  redis_generation    = "redis-generation-1"
}

output "db_password_version" { value = module.secrets.db_password_version }
output "redis_token_version" { value = module.secrets.redis_token_version }
output "database_url_secret_version" { value = module.secrets.database_url_secret_version }
output "redis_url_secret_version" { value = module.secrets.redis_url_secret_version }
output "secret_arns" { value = module.secrets.secret_arns }
output "database_url_query" { value = module.secrets.database_url_query }
