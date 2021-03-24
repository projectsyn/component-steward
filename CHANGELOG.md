# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v2.0.0]

### Changed
- Upgrade Steward from v1.2 to v3.1 and ArgoCD from v1.7.4 to 1.8.7 ([#4])

### BREAKING CHANGES
- The version v2.0.0 does use a statefulset instead of a deployment and is only compatible with ArgoCD 1.8.
- It requires the argocd component v2.0.0.

## [v1.0.0]

### Changed

- Open source component ([#2])
- Configure Argo CD image to be deployed ([#5])

[Unreleased]: https://github.com/projectsyn/component-steward/compare/v2.0.0...HEAD
[v1.0.0]: https://github.com/projectsyn/component-steward/releases/tag/v1.0.0
[v2.0.0]: https://github.com/projectsyn/component-steward/releases/tag/v2.0.0

[#2]: https://github.com/projectsyn/component-steward/pull/2
[#4]: https://github.com/projectsyn/component-steward/pull/4
[#5]: https://github.com/projectsyn/component-steward/pull/5
