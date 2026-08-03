# Security Policy

## Reporting a Vulnerability

Please report security issues with jaredeberle.org or this repository via:

- [GitHub Private Vulnerability Reporting](https://github.com/jleberle/website/security/advisories/new), or
- the contact and PGP key listed in [`/.well-known/security.txt`](https://jaredeberle.org/.well-known/security.txt)

Please do not open a public GitHub issue for security reports.

## Scope

This is the source for a personal static site (Hugo) and its build/validation
tooling. There is no authentication, user data storage, or backend service —
reports are most useful for things like XSS in generated pages, dependency
vulnerabilities, or CI/supply-chain issues in this repo's workflows.
