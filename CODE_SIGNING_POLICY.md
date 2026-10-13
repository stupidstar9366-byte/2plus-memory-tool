# Code signing policy

## Current status

The project is preparing an application for free open-source signing. It has **not** received SignPath Foundation approval, and no Foundation signature is present on the local preview.

If the application is accepted, the following attribution will be activated here and on the release/download page:

> Free code signing provided by [SignPath.io](https://signpath.io/), certificate by [SignPath Foundation](https://signpath.org/).

This prospective attribution is not a claim of current sponsorship or signing.

## People and responsibilities

The initial project maintainer is the public GitHub repository owner:

- Committer and reviewer: [stupidstar9366-byte](https://github.com/stupidstar9366-byte).
- Release signing approver: [stupidstar9366-byte](https://github.com/stupidstar9366-byte).

All source-hosting and SignPath team accounts must use multi-factor authentication before signing is activated. Contributions from other authors are reviewed before merging. Every production signing request requires the designated human approver's review in SignPath.

## Release path

1. Build the reviewed source on a GitHub-hosted Windows runner.
2. Run the configuration, backup/restore and release checks.
3. Upload the unsigned artifact to the same GitHub Actions run.
4. Submit that artifact with GitHub origin information to the approved SignPath project.
5. Have the designated human approver review the request.
6. Verify the resulting Authenticode signature, publisher and timestamp on Windows.
7. Generate new checksums from the signed EXE, then publish that unchanged binary. The same binary may be shared on Discord.

The signing workflow can run only by manual dispatch from `main`, after `SIGNPATH_READY` is set to `true`. Signing is never run for pull-request builds. Signing credentials belong in GitHub Actions secrets and must not be committed or pasted into issues.

See [PRIVACY.md](PRIVACY.md) for the app's data handling. A valid signature does not guarantee any specific antivirus or SmartScreen verdict.
