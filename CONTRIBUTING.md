# Contributing to VOIDWAVE

Thank you for investing your time in contributing to VOIDWAVE! Any contribution you make helps improve the project :sparkles:

Read our [Code of Conduct](./CODE_OF_CONDUCT.md) to keep our community approachable and respectable.

Use the table of contents icon <img alt="Table of contents icon" src="./assets/images/table-of-contents.png" width="25" height="25" /> in the top corner of this document to navigate to a specific section quickly.

## New Contributor Guide

To get an overview of the project, read the [README](README.md). Here are some resources to help you get started with open source contributions:

- [Finding ways to contribute to open source on GitHub](https://docs.github.com/en/get-started/exploring-projects-on-github/finding-ways-to-contribute-to-open-source-on-github)
- [Set up Git](https://docs.github.com/en/get-started/git-basics/set-up-git)
- [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow)
- [Collaborating with pull requests](https://docs.github.com/en/github/collaborating-with-pull-requests)

## Platform Requirements

> **⚠️ Linux Only**: VOIDWAVE requires Linux for development and usage. Windows is not supported due to dependencies on Linux-specific tools and system calls.

Supported distributions:
- Debian / Ubuntu
- Fedora / RHEL
- Arch Linux
- openSUSE
- Alpine Linux

## Contribution Types

### What We Accept

- Bug fixes and patches
- New features aligned with project goals
- Documentation improvements
- Test coverage improvements
- Performance optimizations
- Security fixes
- Support for additional Linux distributions

### What We Don't Accept

- Breaking changes without discussion
- Features outside project scope
- Cosmetic-only changes with no functional benefit
- Dependencies that significantly increase project size without clear benefit
- Windows or macOS compatibility requests

If you're unsure whether your contribution fits, open an issue to discuss it first.

## Getting Started

### Issues

#### Create a New Issue

If you spot a problem or have a feature request, [search if an issue already exists](https://github.com/Nerds489/VOIDWAVE/issues). If a related issue doesn't exist, you can open a new issue using the appropriate [issue template](https://github.com/Nerds489/VOIDWAVE/issues/new/choose).

#### Solve an Issue

Scan through our [existing issues](https://github.com/Nerds489/VOIDWAVE/issues) to find one that interests you. You can narrow down the search using `labels` as filters. As a general rule, issues are not assigned. If you find an issue to work on, you are welcome to open a PR with a fix.

### Making Changes

#### Make Changes Locally

1. **Fork the repository**
   - Using GitHub Desktop: [Getting started with GitHub Desktop](https://docs.github.com/en/desktop/installing-and-configuring-github-desktop/getting-started-with-github-desktop)
   - Using the command line: [Fork the repo](https://docs.github.com/en/github/getting-started-with-github/fork-a-repo#fork-an-example-repository)

2. **Clone your fork**
```bash
   git clone https://github.com/YOUR-USERNAME/VOIDWAVE.git
   cd VOIDWAVE
```

3. **Create a working branch**
```bash
   git checkout -b feature/your-feature-name
```

4. **Make your changes**
   - Follow the coding standards outlined below
   - Write or update tests as needed
   - Update documentation if applicable

### Coding Standards

- Follow existing code style and conventions
- Write clear, descriptive commit messages
- Include comments for complex logic
- Ensure all tests pass before submitting
- Keep changes focused and atomic

### Commit Your Update

Commit the changes once you are happy with them. Use clear, descriptive commit messages:
```bash
git commit -m "feat: add new feature description"
git commit -m "fix: resolve issue with component"
git commit -m "docs: update README with new instructions"
```

**Commit message prefixes:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `style:` - Formatting, no code change
- `refactor:` - Code restructuring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

### Self Review Checklist

Before submitting, review your changes:

- [ ] Code compiles without errors
- [ ] All tests pass
- [ ] New code has appropriate test coverage
- [ ] Documentation is updated if needed
- [ ] Commit messages are clear and descriptive
- [ ] No unrelated changes included
- [ ] Code follows project style guidelines

### Pull Request

When you're finished with the changes, create a pull request (PR).

1. Push your branch to your fork:
```bash
   git push origin feature/your-feature-name
```

2. Open a PR against the `main` branch of VOIDWAVE

3. Fill in the PR template:
   - Describe what your changes do
   - Link any related issues
   - Include screenshots for UI changes

4. Enable the checkbox to [allow maintainer edits](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/allowing-changes-to-a-pull-request-branch-created-from-a-fork)

5. A maintainer will review your PR. We may ask questions or request changes.

### Your PR is Merged!

Congratulations :tada: The VOIDWAVE team thanks you :sparkles:

Once merged, your contributions will be part of the next release.

## Development Setup

### Prerequisites

- Linux operating system (see supported distributions above)
- Git
- Bash 4.0+
- Root/sudo access for system tool installation

### Installation
```bash
# Clone the repository
git clone https://github.com/Nerds489/VOIDWAVE.git
cd VOIDWAVE

# Run installation script (requires root)
sudo ./install.sh

# Verify installation
voidwave --version
```

## Getting Help

- Open an [issue](https://github.com/Nerds489/VOIDWAVE/issues) for bugs or feature requests
- Start a [discussion](https://github.com/Nerds489/VOIDWAVE/discussions) for questions or ideas
- Check existing issues and discussions before creating new ones

## License

By contributing to VOIDWAVE, you agree that your contributions will be licensed under the same license as the project.
