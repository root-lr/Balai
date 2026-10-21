# Security policy

Balai deletes files, so we treat any way to make it delete the wrong thing as a security issue.

## What to report

- A path that gets past `SafetyGuard` and shouldn't (system files, credentials, personal data, Apple apps…)
- A way to make Balai delete something the user didn't select
- A cleanup location that is pre-selected but holds user data that doesn't regenerate
- Anything else that could lead to data loss or run with more privileges than expected

## How to report

Please **don't open a public issue**. Use GitHub's private reporting instead:
**[Report a vulnerability](https://github.com/root-lr/Balai/security/advisories/new)**

Include your macOS version, the Balai version and the steps or path involved. We'll reply as soon as possible and credit you in the fix (unless you'd rather stay anonymous).

## Supported versions

Only the latest release receives fixes. Please update before reporting.

---

*Vous pouvez aussi signaler un problème en français.*
