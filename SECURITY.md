# Security

resdocs reads source code and docstrings from the packages it
documents and publishes the result on a shared origin, so a bug that
lets a docstring, a bundle or a build input run code is a security
bug. So is anything that makes the Action leak its token or run
commands it was not given.

## Reporting

Please report vulnerabilities privately through GitHub: the
repository's Security tab, "Report a vulnerability". Do not open a
public issue for them.

Include the resdocs version or commit, how the site or bundle was
built, and the smallest input that shows the problem. You should get
an answer within a week.

## Supported versions

Fixes land on `main` and ship in the next release. Only the latest
release is supported; before 1.0 that means the latest `v0.<minor>`.

## What resdocs guarantees

- Nothing from a documented package is evaluated, at build time or in
  the browser. Docstrings become a sanitized tree of elements and
  text (`src/core/Doc.res`), sanitized again in the viewer.
- Action inputs reach its shell scripts only through environment
  variables.
- The site title is HTML escaped and `--base` is limited to
  characters that need no escaping.
