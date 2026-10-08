mock_provider "aws" {}

variables {
  name_prefix                = "nnat-test"
  vpc_id                     = "vpc-0123456789abcdef0"
  subnet_ids                 = ["subnet-aaa", "subnet-bbb"]
  allowed_security_group_ids = ["sg-0123456789abcdef0"]
  node_type                  = "cache.t4g.micro"
  auth_token                 = "not-a-real-token-0123456789"
  auth_token_version         = 1
}

run "traffic_and_data_are_encrypted" {
  command = plan

  assert {
    condition     = aws_elasticache_replication_group.this.transit_encryption_enabled == true && aws_elasticache_replication_group.this.at_rest_encryption_enabled == "true"
    error_message = "Redis must encrypt in transit and at rest"
  }
}

run "single_node_has_no_failover" {
  command = plan

  assert {
    condition     = aws_elasticache_replication_group.this.num_cache_clusters == 1 && aws_elasticache_replication_group.this.automatic_failover_enabled == false
    error_message = "zero replicas means one node and no failover"
  }
}

run "replica_enables_failover" {
  command = plan

  variables {
    replicas = 1
  }

  assert {
    condition     = aws_elasticache_replication_group.this.num_cache_clusters == 2 && aws_elasticache_replication_group.this.automatic_failover_enabled == true
    error_message = "one replica means two nodes and automatic failover"
  }
}

run "rate_limit_counters_are_never_evicted" {
  command = plan

  assert {
    condition     = one([for p in aws_elasticache_parameter_group.this.parameter : p.value if p.name == "maxmemory-policy"]) == "noeviction"
    error_message = "the starter keeps rate-limit counters in Redis; evicting them would reset limits"
  }
}

# Review finding I7: a changed AUTH token must take effect now, or the rewritten REDIS_URL and the cache disagree.
run "token_changes_apply_immediately" {
  command = plan

  assert {
    condition     = aws_elasticache_replication_group.this.apply_immediately == true
    error_message = "apply_immediately must be true so a rotated AUTH token is active when the secret is rewritten"
  }
}
