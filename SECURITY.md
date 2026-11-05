# Security policy

## Supported versions

Security fixes go to the latest release.

## Report a vulnerability

Please don't open a public issue. Use [private vulnerability reporting](https://github.com/brayanspagnol/atoll/security/advisories/new)
and include the steps to reproduce and the impact.

You should get a first answer within 7 days. This is a project maintained in spare time, so a fix may take longer.

Atoll handles Wi-Fi passwords in memory only long enough to pass them to NetworkManager, and it runs entirely as
your user, apart from the optional `sudo` steps in `install.sh`.
