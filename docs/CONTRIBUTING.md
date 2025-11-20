# Contributing to handbuilt-linux

Thank you for considering contributing to handbuilt-linux! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce**
- **Expected vs actual behavior**
- **Environment details** (OS, Docker version, etc.)
- **Logs and error messages**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When suggesting an enhancement:

- **Use a clear title**
- **Provide detailed description**
- **Explain why this would be useful**
- **Include examples if applicable**

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/AmazingFeature`)
3. **Make your changes**
4. **Test thoroughly**
5. **Commit with clear messages** (`git commit -m 'Add some AmazingFeature'`)
6. **Push to your fork** (`git push origin feature/AmazingFeature`)
7. **Open a Pull Request**

#### PR Guidelines

- Follow existing code style
- Update documentation as needed
- Add tests for new features
- Ensure all tests pass
- Keep PRs focused on a single change
- Write clear commit messages

## Development Setup

### Prerequisites

```bash
# Install Docker
# Install QEMU (optional, for testing)
brew install qemu  # macOS
sudo apt-get install qemu-system-x86  # Ubuntu
```

### Local Development

```bash
# Clone your fork
git clone https://github.com/yourusername/handbuilt-linux.git
cd handbuilt-linux

# Build the project
make build

# Run tests
make test

# Test with QEMU
make qemu
```

## Code Style

### Shell Scripts

- Use `#!/usr/bin/env bash` for bash scripts
- Use `#!/bin/sh` for POSIX shell scripts
- Enable strict mode: `set -euo pipefail`
- Add function documentation
- Use meaningful variable names
- Quote variables: `"${var}"`

### Dockerfile

- Use multi-stage builds
- Minimize layers
- Use specific base image tags
- Add comments for complex operations
- Group related commands
- Clean up in the same layer

## Testing

### Running Tests

```bash
# Full test suite
make test

# Individual tests
./scripts/test.sh

# Docker build test
make build

# QEMU test
make qemu-nographic
```

### Writing Tests

Add tests to `scripts/test.sh`:

```bash
test_new_feature() {
    log_info "Testing new feature..."
    if some_test_command; then
        log_success "Feature works"
        return 0
    else
        log_error "Feature failed"
        return 1
    fi
}
```

## Documentation

- Update README.md for user-facing changes
- Add comments for complex code
- Update relevant docs in `docs/`
- Include examples where helpful

## Commit Messages

Use clear, descriptive commit messages:

```
Short summary (50 chars or less)

More detailed explanatory text if needed. Wrap at 72 characters.
Explain the problem this commit solves and why you chose this solution.

- Bullet points are okay
- Use present tense ("Add feature" not "Added feature")
- Reference issues: "Fixes #123"
```

## Release Process

1. Update version numbers
2. Update CHANGELOG.md
3. Create release tag
4. GitHub Actions will build and publish

## Questions?

Feel free to open an issue for questions or start a discussion.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
