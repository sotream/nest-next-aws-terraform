# The random provider is real: mock providers cannot serve ephemeral resources. No AWS call is made.
mock_provider "aws" {
  alias = "mock"
}

run "all_three_secrets_exist" {
  command   = plan
  providers = { aws = aws.mock }

  module {
    source = "./tests/harness"
  }

  assert {
    condition     = length(keys(output.secret_arns)) == 3
    error_message = "expected database_url, redis_url and jwt_access_secret"
  }
}

# The database and cache modules receive these. They must not depend on the host: the host is an output of
# the very resource that consumes the version, so that would be a dependency cycle.
run "password_versions_equal_credentials_version" {
  command   = plan
  providers = { aws = aws.mock }

  module {
    source = "./tests/harness"
  }

  variables {
    credentials_version = 4
  }

  assert {
    condition     = output.db_password_version == 4 && output.redis_token_version == 4
    error_message = "db and redis versions must equal credentials_version"
  }
}

run "rotation_rewrites_both_url_secrets" {
  command   = plan
  providers = { aws = aws.mock }

  module {
    source = "./tests/harness"
  }

  variables {
    credentials_version = 4
  }

  assert {
    condition     = output.database_url_secret_version - 4 == parseint(substr(md5("db-generation-1"), 0, 6), 16) && output.redis_url_secret_version - 4 == parseint(substr(md5("redis-generation-1"), 0, 6), 16)
    error_message = "both URL secret versions must move by exactly the credentials_version delta"
  }
}

# Review finding I1: an endpoint is deterministic for a fixed identifier, so a replaced instance keeps its host.
# A generation id that changes on replacement must drive the URL secret version instead.
run "replacement_with_the_same_host_rewrites_the_url_secret" {
  command   = plan
  providers = { aws = aws.mock }

  module {
    source = "./tests/harness"
  }

  variables {
    db_generation = "db-generation-2"
  }

  assert {
    condition     = output.database_url_secret_version != parseint(substr(md5("db-generation-1"), 0, 6), 16) + 1
    error_message = "a new database generation (same host) must rewrite the DATABASE_URL secret"
  }
}

run "database_url_asks_for_tls" {
  command   = plan
  providers = { aws = aws.mock }

  module {
    source = "./tests/harness"
  }

  assert {
    condition     = output.database_url_query == "sslmode=no-verify"
    error_message = "DATABASE_URL must carry sslmode so the starter connects over TLS (ADR 0008)"
  }
}
