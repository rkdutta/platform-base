# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0]

### Added

- Argo Rollouts (progressive delivery controller) installed via its Helm chart,
  pinned to chart `2.41.0` (app `v1.9.0`). Toggle with `argo_rollouts_enabled`.

## [0.1.0] - 2026-07-10

### Added

- Terraform configuration to provision a local [kind](https://kind.sigs.k8s.io/)
  cluster (`kind_cluster.this`) with a control-plane node and a configurable
  number of worker nodes.
- Ingress-ready control-plane node with host ports mapped (defaults 8080/8443)
  so an ingress controller can be installed later.
- Argo CD installed via its Helm chart, pinned to chart `10.1.3` (app `v3.4.5`).
- Input variables, outputs (kubeconfig path, kubectl context, Argo CD helper
  commands), and `example.tfvars`.
- Release management: this changelog, semantic-versioned Git tags, `RELEASING.md`,
  and CI/release GitHub Actions workflows.

[Unreleased]: https://github.com/rkdutta/platform-base/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/rkdutta/platform-base/releases/tag/v0.1.0
