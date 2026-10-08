#!/usr/bin/env bash
# Prints the image tag the given ECS service runs right now, or nothing when the service does not exist.
# The deploy and plan workflows use it instead of a Terraform output: an output is written from variables
# even when a rollout failed and ECS rolled back, so it can name a tag that is not actually running.
#
# Usage: current-image-tag.sh CLUSTER SERVICE
set -euo pipefail

cluster=$1
service=$2

task_definition=$(aws ecs describe-services --cluster "$cluster" --services "$service" \
  --query 'services[?status==`ACTIVE`] | [0].taskDefinition' --output text)

if [ -z "$task_definition" ] || [ "$task_definition" = "None" ]; then
  exit 0
fi

image=$(aws ecs describe-task-definition --task-definition "$task_definition" \
  --query 'taskDefinition.containerDefinitions[0].image' --output text)

# repository:tag, with a registry port or a digest handled by taking only a trailing :tag after the last slash.
last=${image##*/}
case "$last" in
  *@*) exit 0 ;;
  *:*) echo "${last##*:}" ;;
esac
