output "state_bucket" {
  description = "Name of the Terraform state bucket; pass it as -backend-config=bucket=..."
  value       = aws_s3_bucket.state.id
}

output "plan_role_arn" {
  description = "Role the plan workflow assumes. Store it as the repository variable AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.plan.arn
}

output "deploy_role_arns" {
  description = "Deploy role ARNs keyed by environment. Store each as AWS_DEPLOY_ROLE_ARN in the matching GitHub Environment."
  value       = { for env, r in aws_iam_role.deploy : env => r.arn }
}

output "permissions_boundary_arn" {
  description = "Boundary the deploy role requires on every role the stack creates. Pass it as permissions_boundary_arn."
  value       = aws_iam_policy.boundary.arn
}
