# 0007. Kafka on AWS: MSK or self-hosted, not built

- Status: accepted
- Date: 2026-10-08

## Context

The starter has an optional Kafka integration behind `KAFKA_ENABLED` (default `false`) and an
`EventPublisher` port with a no-op adapter. See the starter's
[ADR 0005](https://github.com/sotream/nest-next-starter/blob/main/docs/adr/0005-kafka-optional.md). This
deployment leaves it off.

## Decision

Do not build Kafka. `KAFKA_ENABLED=false` is set explicitly on the API and the migration task. If it is
needed later, the two options are:

- **Amazon MSK** (provisioned or serverless). Managed brokers inside the VPC, IAM or SCRAM authentication.
  Costs a fixed amount per broker-hour (three brokers minimum for production) or per partition-hour for
  serverless, which dwarfs the rest of this stack. The starter connects with plain `KAFKA_BROKERS`, so SCRAM
  or TLS settings would need starter changes; check the starter's client options first.
- **Self-hosted KRaft on ECS or EC2.** Cheaper at small scale, but you own storage, upgrades, rebalancing and
  durability. Not recommended beyond a demo.

## Consequences

- No Kafka cost or operational surface now.
- What a later change touches: a `messaging` module (cluster, security group allowing the API task group), a
  `KAFKA_ENABLED=true` and `KAFKA_BROKERS` environment on the API, a secret if the cluster needs credentials,
  and an alarm for consumer lag.
- The starter's Kafka integration has never been run on AWS.
