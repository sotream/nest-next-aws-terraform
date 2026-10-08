# 0006. Trust proxy behind the ALB

- Status: accepted
- Date: 2026-10-08

## Context

The starter's [ADR 0007](https://github.com/sotream/nest-next-starter/blob/main/docs/adr/0007-no-trust-proxy.md)
chose not to enable `trust proxy`: the API identifies clients by `req.ip`, and behind a proxy that is the
proxy's address. This deployment puts an Application Load Balancer in front of the API, which is exactly the
case that ADR warns about. The starter must not be modified here.

## Decision

Deploy the starter as it is and **document the consequence instead of working around it**. Do not set
`trust proxy` through any environment variable or image patch, and do not suggest `trust proxy: true`: it
trusts any `X-Forwarded-For`, so a forged header would give every request a fresh identity.

## Consequences

- The API sees the private IP of an ALB node (one per zone) for every request. Rate limits are shared by all
  clients that happen to reach the same node: sign-in (10 per minute) and refresh (60 per minute) can lock
  everyone out, and an attacker gets no per-IP throttle.
- IP addresses in the API logs are the ALB's, not the clients'. The ALB can log real client addresses if
  access logging is enabled (off by default, see the [cost estimate](../guides/cost-estimate.md)).
- This deployment is suitable for a demo or low-traffic use, not for a public sign-in endpoint.
- TLS is terminated on the ALB. That is fine for the cookie rules (`Secure` follows `APP_ENV`), the starter
  only documents it as unsupported because of the proxy address problem above.

## When to revisit

When the starter gains a `TRUST_PROXY` setting (a hop count, not `true`), set it to `1` for this topology:
exactly one trusted proxy, the ALB. The ALB appends the connecting address to any `X-Forwarded-For` the client
sent, so the starter must take the entry added by the nearest trusted hop, which is what a hop count does. An
AWS WAF rate-based rule on the ALB is an infrastructure mitigation that works today, at a fixed monthly cost,
and is not included.
