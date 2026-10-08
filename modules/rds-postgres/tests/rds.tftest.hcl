mock_provider "aws" {
  # Mocked data sources return random strings; the KMS key validates its policy as JSON.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name_prefix                = "nnat-test"
  vpc_id                     = "vpc-0123456789abcdef0"
  subnet_ids                 = ["subnet-aaa", "subnet-bbb"]
  allowed_security_group_ids = ["sg-0123456789abcdef0"]
  instance_class             = "db.t4g.micro"
  password                   = "not-a-real-password"
  password_version           = 1
}

run "database_is_private_and_encrypted" {
  command = plan

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false && aws_db_instance.this.storage_encrypted == true
    error_message = "the database must be private and encrypted"
  }
}

run "multi_az_follows_the_variable" {
  command = plan

  variables {
    multi_az = true
  }

  assert {
    condition     = aws_db_instance.this.multi_az == true
    error_message = "multi_az must be passed through"
  }
}

run "tls_is_required_for_connections" {
  command = plan

  assert {
    condition     = one([for p in aws_db_parameter_group.this.parameter : p.value if p.name == "rds.force_ssl"]) == "1"
    error_message = "rds.force_ssl must be 1: the starter can connect over TLS through ?sslmode= in DATABASE_URL (ADR 0008)"
  }
}

run "parameter_group_family_follows_major_version" {
  command = plan

  variables {
    engine_version = "17.4"
  }

  assert {
    condition     = aws_db_parameter_group.this.family == "postgres17"
    error_message = "family must be derived from the engine major version"
  }
}

run "protected_database_keeps_a_final_snapshot" {
  command = plan

  variables {
    deletion_protection = true
  }

  assert {
    condition     = aws_db_instance.this.skip_final_snapshot == false && aws_db_instance.this.deletion_protection == true
    error_message = "a protected database must take a final snapshot"
  }
}

# Review finding I5: unprotecting a database to destroy it must not silently drop the final snapshot.
run "final_snapshot_is_independent_of_deletion_protection" {
  command = plan

  variables {
    deletion_protection = false
    final_snapshot      = true
  }

  assert {
    condition     = aws_db_instance.this.skip_final_snapshot == false
    error_message = "final_snapshot = true must take a snapshot even when deletion protection is off"
  }
}

run "final_snapshot_can_be_skipped_for_disposable_environments" {
  command = plan

  variables {
    final_snapshot = false
  }

  assert {
    condition     = aws_db_instance.this.skip_final_snapshot == true
    error_message = "final_snapshot = false skips the snapshot"
  }
}
