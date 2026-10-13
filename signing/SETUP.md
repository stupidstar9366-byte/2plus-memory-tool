# SignPath Foundation setup

This file describes pending setup. It does not mean an application has been submitted or accepted.

1. Publish the source repository and a documented unsigned preview release.
2. Record the maintainer and signing approver's GitHub account in `CODE_SIGNING_POLICY.md`. Enable MFA on contributor accounts and SignPath accounts.
3. Apply at <https://signpath.org/apply.html>, including repository/homepage/download links and real evidence of use. New projects are not guaranteed acceptance.
4. After acceptance, add the SignPath GitHub integration for this repository, link the trusted GitHub build system, and create a project artifact configuration from `artifact-configuration.xml`.
5. Configure a production signing policy with a human approval requirement. The certificate is issued in SignPath Foundation's name, not in the name of this Discord server.
6. Set Actions secret `SIGNPATH_API_TOKEN` and variables `SIGNPATH_ORGANIZATION_ID`, `SIGNPATH_PROJECT_SLUG`, `SIGNPATH_SIGNING_POLICY_SLUG`. Use the actual values supplied by SignPath.
7. Only after approval and setup, activate the attribution on the homepage/release page and set `SIGNPATH_READY=true`.
8. Run **Build and test** manually on `main` with `request_signing=true`. Approve the request in SignPath and wait for Windows signature/timestamp verification.
9. Publish the verified signed artifact without modifying its EXE. Recompute checksums after signing; do not reuse unsigned hashes. The same EXE can be attached to Discord.

Do not upload arbitrary local binaries for signing or reuse someone else's certificate. Do not claim that signing guarantees the absence of antivirus warnings.

References: [Foundation terms](https://signpath.org/terms.html), [GitHub integration](https://docs.signpath.io/trusted-build-systems/github), [artifact configuration](https://docs.signpath.io/artifact-configuration/examples).
