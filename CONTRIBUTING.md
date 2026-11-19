# Contributing to Jetlag

Thank you for your interest in contributing to Jetlag! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Community](#community)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow. By participating, you are expected to uphold this standard. Please be respectful, inclusive, and professional in all interactions.

## Getting Started

### Prerequisites

Before you begin contributing, ensure you have:

- **Ansible 4.10+** (core >= 2.11.12) installed
- **Python 3.6+** with pip
- **Git** for version control
- **RHEL 9.4+** available for testing (bastion/hypervisor nodes)
- Access to one of the supported environments:
  - Red Hat Performance Lab
  - Red Hat Scale Lab
  - IBMcloud (Bare Metal)
  - Or a "Bring Your Own Lab" setup

### Understanding the Project

Before contributing, familiarize yourself with:

- **[README.md](README.md)** - Project overview and basic usage
- **[CLAUDE.md](CLAUDE.md)** - Comprehensive deployment guide and essential commands
- **[AGENT.md](AGENT.md)** - Development-focused guide for working with the codebase
- **[docs/](docs/)** - Detailed documentation on specific topics

### Key Concepts

Jetlag deploys OpenShift clusters via Assisted Installer in three main layouts:
- **MNO** (Multi Node OpenShift): 3 control-plane + N worker nodes
- **SNO** (Single Node OpenShift): One cluster per available machine
- **VMNO** (Virtual Multi Node OpenShift): MNO using VMs instead of bare metal

## Development Setup

### 1. Fork and Clone

Fork the repository on GitHub, then clone your fork:

```bash
git clone https://github.com/YOUR-USERNAME/jetlag.git
cd jetlag
```

Add the upstream repository as a remote:

```bash
git remote add upstream https://github.com/UPSTREAM-ORG/jetlag.git
```

### 2. Set Up Ansible Environment

Bootstrap the Ansible virtual environment:

```bash
source bootstrap.sh
```

This creates a Python virtual environment and installs required Ansible collections and dependencies.

### 3. Install Development Tools

For linting and validation:

```bash
pip install yamllint
```

### 4. Configure Your Environment

Copy sample configuration files:

```bash
# For Red Hat labs
cp ansible/vars/all.sample.yml ansible/vars/all.yml

# For IBMcloud
cp ansible/vars/ibmcloud.sample.yml ansible/vars/ibmcloud.yml
```

Edit the configuration files according to your test environment.

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

- **Bug fixes** - Fix issues in deployment logic, configuration, or documentation
- **New features** - Add support for new hardware, environments, or capabilities
- **Documentation improvements** - Clarify, expand, or correct documentation
- **Testing** - Improve test coverage and validation
- **Hardware support** - Add new hardware definitions to `ansible/vars/lab.yml`
- **Examples and guides** - Add deployment guides or troubleshooting tips

### Contribution Workflow

1. **Check existing issues** - Look for related issues or discussions
2. **Create an issue** - Describe the problem or feature (if one doesn't exist)
3. **Create a branch** - Use descriptive branch names
4. **Make changes** - Follow coding standards (see below)
5. **Test thoroughly** - Validate in a real or simulated environment
6. **Submit a PR** - Reference the related issue
7. **Address feedback** - Respond to review comments

### Branch Naming

Use descriptive branch names following this pattern:

- `fix/short-description` - Bug fixes
- `feature/short-description` - New features
- `docs/short-description` - Documentation changes
- `refactor/short-description` - Code refactoring
- `test/short-description` - Test improvements

Examples:
- `fix/bastion-haproxy-ipv6`
- `feature/add-r7725-hardware`
- `docs/update-troubleshooting-guide`

## Coding Standards

### Ansible Style Guidelines

#### YAML Formatting

- **Indentation**: Use 2 spaces (no tabs)
- **Line length**: No strict limit, but keep it reasonable
- **File start**: Begin with `---`
- **Boolean values**: Use `true`/`false` (not `yes`/`no`)

Example:
```yaml
---
- name: Configure bastion services
  hosts: bastion
  gather_facts: true
  tasks:
    - name: Install required packages
      ansible.builtin.dnf:
        name:
          - podman
          - dnsmasq
        state: present
```

#### Task Naming

- Start with a capital letter
- Use present tense (e.g., "Install package" not "Installing package")
- Be specific and descriptive
- Describe what the task does, not how

Good examples:
```yaml
- name: Create Assisted Installer cluster definition
- name: Configure bastion network interfaces
- name: Wait for nodes to appear in cluster
```

Avoid:
```yaml
- name: Do stuff
- name: Fix things
- name: Update
```

#### Variable Naming

Use descriptive snake_case names with appropriate prefixes:

- `bastion_*` - Bastion host configuration
- `setup_*` - Boolean feature flags
- `enable_*` - Feature toggles
- `ocp_*` - OpenShift-specific settings
- `controlplane_*` - Control plane network settings

Examples:
```yaml
# Good
setup_local_storage: true
bastion_controlplane_interface: ens1f0
ocp_version: "4.20"

# Avoid
lso: yes
iface: ens1f0
version: "4.20"
```

#### Module Usage

- Use fully qualified collection names (FQCN): `ansible.builtin.copy`
- Prefer built-in modules over shell commands
- Use appropriate modules for the task:
  - `ansible.builtin.uri` for HTTP APIs
  - `community.general.redfish_*` for Dell BMCs
  - `ansible.builtin.dnf` for package management
  - `ansible.builtin.systemd` for service management
  - `ansible.builtin.template` for configuration files

Example:
```yaml
# Preferred
- name: Install packages
  ansible.builtin.dnf:
    name: podman
    state: present

# Avoid
- name: Install packages
  shell: dnf install -y podman
```

#### Idempotency

All tasks should be idempotent (safe to run multiple times):

```yaml
# Use creates to prevent re-running
- name: Download file
  get_url:
    url: http://example.com/file.tar.gz
    dest: /tmp/file.tar.gz
  args:
    creates: /tmp/file.tar.gz

# Check state before changing
- name: Enable service
  ansible.builtin.systemd:
    name: podman
    enabled: true
    state: started
```

#### Error Handling

Implement retries for flaky operations:

```yaml
- name: Power on machine via BMC
  community.general.redfish_command:
    category: Systems
    command: PowerOn
    baseuri: "{{ bmc_address }}"
    username: "{{ bmc_user }}"
    password: "{{ bmc_password }}"
  retries: 3
  delay: 10
  register: result
  until: result is succeeded
```

### Documentation Standards

#### Code Comments

- Comment the "why," not the "what"
- Explain non-obvious logic or workarounds
- Reference issue numbers for workarounds
- Keep comments concise

Example:
```yaml
# Workaround for OCPBUGS-12345 - virtual media sometimes fails to mount
# on first attempt with Dell r750 BMCs
- name: Retry virtual media mount
  ...
```

#### Variable Documentation

Document all variables in sample files with:
- Purpose description
- Possible values
- Default value (if applicable)
- When to use/change

Example:
```yaml
# Storage class to set as default (RWO/RWX capable)
# Options: ocs-storagecluster-cephfs, localstorage-sc, localstorage-disk-sc
# Default: Automatically selected based on setup_odf/setup_lso
# Set this to override automatic selection
# default_storage_class: ocs-storagecluster-cephfs
```

#### Markdown Documentation

- Use clear headings and table of contents
- Include code examples where applicable
- Provide context and explain why, not just what
- Link to related documentation
- Keep examples up to date

### Hardware Definitions

**CRITICAL**: Never manually edit `ansible/vars/lab.yml`

When adding new hardware support:

1. Use the `hw-onboard` skill with Claude Code
2. The skill will discover NIC and disk configurations
3. The skill will update `lab.yml` with proper formatting
4. Test the new hardware definition thoroughly
5. Submit a PR with the hardware addition

Example PR description:
```
Add r7725 hardware support

- Discovered via hw-onboard skill
- Tested with MNO deployment in Scale Lab
- NIC interfaces: eno8303, eno8403
- Disks: /dev/nvme0n1, /dev/nvme1n1
```

## Testing Guidelines

### Required Testing

All contributions must be tested before submission:

#### 1. YAML Linting

Run yamllint locally before committing:

```bash
yamllint .
```

Fix any errors or warnings. The yamllint configuration is in `.yamllint`.

#### 2. Syntax Validation

Validate Ansible playbook syntax:

```bash
ansible-playbook --syntax-check ansible/mno-deploy.yml
ansible-playbook --syntax-check ansible/sno-deploy.yml
```

#### 3. Functional Testing

Test in a real or simulated environment:

- **For bug fixes**: Verify the fix resolves the issue
- **For new features**: Test all supported cluster types (MNO/SNO/VMNO)
- **For hardware support**: Test on actual hardware
- **For networking changes**: Test in multiple environments
- **For storage changes**: Verify LSO and ODF configurations

#### 4. Regression Testing

Ensure your changes don't break existing functionality:

- Test with default configuration
- Test with common customizations
- Test with disabled features
- Verify backward compatibility

### Test Environments

If you have access to Red Hat labs:
- Use the Scale Lab or Performance Lab
- Allocate a cloud with sufficient machines
- Test with representative hardware

For IBMcloud:
- Use IBMcloud bare metal instances
- Test the `ibmcloud-*` playbooks

For "Bring Your Own Lab":
- Ensure minimum requirements are met
- Document any special considerations

### Testing Checklist

Before submitting a PR, verify:

- [ ] yamllint passes
- [ ] Ansible syntax check passes
- [ ] Tested on MNO cluster type (if applicable)
- [ ] Tested on SNO cluster type (if applicable)
- [ ] Tested on VMNO cluster type (if applicable)
- [ ] Variable samples updated (if new variables added)
- [ ] Documentation updated (if user-facing changes)
- [ ] Idempotent (safe to re-run)
- [ ] Works with feature disabled (if optional feature)
- [ ] No hardcoded values (uses variables)
- [ ] No sensitive data committed

## Pull Request Process

### 1. Keep Changes Focused

- One feature or fix per PR
- Avoid mixing unrelated changes
- Keep PRs reasonably sized for review

### 2. Write a Clear PR Description

Use this template:

```markdown
## Description
Brief description of what this PR does and why.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Hardware support
- [ ] Refactoring
- [ ] Other (specify)

## Related Issue
Fixes #123

## Testing Performed
- Tested on MNO cluster in Scale Lab cloud42
- Verified with OCP 4.20 GA
- Tested with LSO and ODF storage configurations

## Checklist
- [x] yamllint passes
- [x] Ansible syntax check passes
- [x] Tested in lab environment
- [x] Documentation updated
- [x] Variable samples updated (if applicable)
- [x] Backward compatible
```

### 3. Ensure CI Passes

The yamllint GitHub Action must pass before merge. Check the Actions tab on your PR.

### 4. Request Review

PRs require approval from maintainers listed in the [OWNERS](OWNERS) file:
- Approvers can approve and merge PRs
- Reviewers can provide feedback and suggestions

### 5. Address Feedback

- Respond to all review comments
- Make requested changes or explain why not
- Push updates to the same branch
- Re-request review after addressing feedback

### 6. Merge Process

- **Approvers** will merge your PR after approval
- PRs typically use **squash and merge** for clean history
- Ensure commit messages are clear and descriptive

### 7. After Merge

- Delete your branch (if from your fork)
- Pull the latest main branch
- Update your fork

```bash
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

## Issue Reporting

### Before Reporting

1. **Search existing issues** - Check if already reported
2. **Check documentation** - Review [docs/troubleshooting.md](docs/troubleshooting.md)
3. **Verify version** - Use the latest version of Jetlag

### Creating an Issue

Use the issue template (if available) or include:

#### For Bug Reports

```markdown
**Description**
Clear description of the bug

**Steps to Reproduce**
1. Configure all.yml with...
2. Run playbook...
3. Observe error...

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- Jetlag version/commit: abc123
- Lab: Scale Lab / Performance Lab / IBMcloud
- Hardware: Dell r750
- OCP version: 4.20 GA
- Cluster type: MNO / SNO / VMNO

**Logs/Output**
```
Paste relevant logs or error messages
```

**Additional Context**
Any other relevant information
```

#### For Feature Requests

```markdown
**Feature Description**
Clear description of the proposed feature

**Use Case**
Why is this feature needed? What problem does it solve?

**Proposed Solution**
How should it work? Include examples if possible.

**Alternatives Considered**
Other approaches you've considered

**Additional Context**
Any other relevant information
```

### Issue Labels

Common labels used:
- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Documentation improvements
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention needed
- `hardware` - Hardware-specific issues
- `question` - Further information requested

## Community

### Getting Help

- **Documentation**: Check [CLAUDE.md](CLAUDE.md) and [docs/](docs/)
- **Issues**: Search existing issues or create a new one
- **Discussions**: Use GitHub Discussions (if enabled)

### Stay Updated

- Watch the repository for notifications
- Review merged PRs to learn about changes
- Check the commit history for recent updates

### Recognition

Contributors are recognized through:
- Git commit history
- GitHub contributor statistics
- Mentions in release notes (for significant contributions)

## Additional Resources

### Essential Documentation

- [README.md](README.md) - Project overview
- [CLAUDE.md](CLAUDE.md) - User-facing deployment guide
- [AGENT.md](AGENT.md) - Development-focused guide
- [docs/troubleshooting.md](docs/troubleshooting.md) - Troubleshooting guide
- [docs/tips-and-vars.md](docs/tips-and-vars.md) - Advanced configuration

### Deployment Guides

- [docs/deploy-mno.md](docs/deploy-mno.md) - MNO deployment
- [docs/deploy-sno.md](docs/deploy-sno.md) - SNO deployment
- [docs/deploy-vmno.md](docs/deploy-vmno.md) - VMNO deployment
- [docs/deploy-mno-ibmcloud.md](docs/deploy-mno-ibmcloud.md) - IBMcloud deployment

### Specialized Topics

- [docs/bastion-setup.md](docs/bastion-setup.md) - Bastion configuration
- [docs/local-storage.md](docs/local-storage.md) - LSO setup
- [docs/odf.md](docs/odf.md) - ODF configuration
- [docs/hypervisors.md](docs/hypervisors.md) - Hypervisor management

### External Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [OpenShift Assisted Installer](https://github.com/openshift/assisted-installer)
- [OpenShift Documentation](https://docs.openshift.com/)

## License

By contributing to Jetlag, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).

---

Thank you for contributing to Jetlag! Your efforts help improve OpenShift cluster deployment for the entire community.
