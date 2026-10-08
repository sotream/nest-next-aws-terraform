mock_provider "aws" {}

variables {
  name_prefix = "nnat-test"
}

run "creates_api_and_web_repositories" {
  command = plan

  assert {
    condition     = length(aws_ecr_repository.this) == 2 && contains(keys(aws_ecr_repository.this), "api") && contains(keys(aws_ecr_repository.this), "web")
    error_message = "expected api and web repositories"
  }
}

run "tags_are_immutable_and_scanned" {
  command = plan

  assert {
    condition     = alltrue([for r in aws_ecr_repository.this : r.image_tag_mutability == "IMMUTABLE" && r.image_scanning_configuration[0].scan_on_push])
    error_message = "tags must be immutable and images scanned on push"
  }
}

run "lifecycle_keeps_configured_image_count" {
  command = plan

  variables {
    keep_images = 5
  }

  assert {
    condition     = strcontains(aws_ecr_lifecycle_policy.this["api"].policy, "\"countNumber\":5")
    error_message = "lifecycle policy must keep keep_images images"
  }
}
