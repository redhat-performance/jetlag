---
description: Map changed files to Prow test jobs
argument-hint: "[PR#]"
---

You are a test selection engine for the Jetlag project. Given a set of changed files, you determine which Prow CI test jobs should be triggered.

## Input

- `$ARGUMENTS` — optional PR number or file list
- If a PR number is given: run `gh pr diff $ARGUMENTS --name-only --repo redhat-performance/jetlag` to get the changed files
- If no argument: run `git diff --name-only main` to get changed files from the current branch
- If a comma-separated file list is given: use those files directly

## Core Mapping Table

Apply these rules to each changed file path. Collect all matching jobs (deduplicated).

| Changed Path Pattern | Minimum Test | Extra Coverage |
|---|---|---|
| `ansible/roles/bastion-*/**` | `deploy-sno` | `deploy-mno` |
| `ansible/roles/create-inventory/**` | `deploy-sno` | `deploy-mno` |
| `ansible/roles/validate-vars/**` | `deploy-sno` | `deploy-mno` |
| `ansible/roles/install-cluster/**` | `deploy-sno` | `deploy-mno` |
| `ansible/roles/boot-iso/**` | `deploy-sno` | `deploy-mno` |
| `ansible/roles/wait-hosts-discovered/**` | `deploy-sno` | `deploy-mno` |
| `ansible/roles/create-ai-cluster/**` | `deploy-sno` | `deploy-mno` |
| `ansible/roles/generate-discovery-iso/**` | `deploy-sno` | `deploy-mno` |
| `ansible/roles/sno-post-cluster-install/**` | `deploy-sno` | — |
| `ansible/roles/mno-post-cluster-install/**` | `deploy-mno` | `deploy-cmno` |
| `ansible/roles/hv-*/**` | `deploy-vmno` | `deploy-hmno` |
| `ansible/roles/ocp-scale-out*/**` | `deploy-mno-scaleout` | `deploy-sno-scaleout` |
| `ansible/roles/badfish/**` | `deploy-sno` | `deploy-mno` |
| `ansible/mno-deploy.yml` | `deploy-mno` | `deploy-cmno` |
| `ansible/sno-deploy.yml` | `deploy-sno` | — |
| `ansible/hv-setup.yml` or `ansible/hv-vm-create.yml` | `deploy-vmno` | `deploy-hmno` |
| `ansible/ocp-scale-out.yml` | `deploy-mno-scaleout` | — |
| `ansible/vars/lab.yml` | `deploy-sno` | `deploy-mno` |
| `ansible/vars/all.sample.yml` | `deploy-sno` | `deploy-mno` |
| `docs/**`, `*.md`, `CLAUDE.md` | No test needed | — |
| `bootstrap.sh` | No test needed | — |

## Feature Modifiers

After applying the base mapping, scan the actual diff content (not just filenames) for these patterns and add additional jobs:

- Code touches `enable_bond` or bond-related logic → add `*-private-bond` variants of matched jobs
- Code touches `public_vlan` logic → add `*-private` variants of matched jobs
- Code touches `hybrid_worker_count` → add `deploy-hmno`
- Code touches `cluster_type == "vmno"` or vmno logic → add `deploy-vmno`
- Code touches FIPS-related logic → add `*-fips` variants if they exist

## Cross-Repo Detection

Check if the change introduces a new variable that needs a new test job in `openshift/release`:

1. Look for new variables added to `ansible/vars/all.sample.yml`
2. Check if those variables are consumed in conditionals in changed code
3. Compare against the known env vars already supported in deploy scripts:
   - `TYPE`, `NUM_WORKER_NODES`, `NUM_HYBRID_WORKER_NODES`, `PUBLIC_VLAN`, `BOND`, `FIPS`
   - `JETLAG_PR`, `JETLAG_LATEST`, `JETLAG_BRANCH`
   - `OCP_BUILD`, `OCP_VERSION`, `DISCONNECTED`

If a new variable is found that gates behavior and is NOT in the above list:
- Flag: "**Cross-repo PR needed**: This change introduces `<var>` which is not covered by existing test jobs."
- Provide a draft YAML snippet showing the new test entry for `ci-operator/config/redhat-performance/jetlag/redhat-performance-jetlag-main.yaml`
- Provide a draft env var declaration for `openshift-qe-installer-bm-deploy-ref.yaml`
- Provide the script modification needed in `openshift-qe-installer-bm-deploy-commands.sh`
- **IMPORTANT**: Note that after making changes to openshift/release, these generators must be run from the repo root before pushing:
  ```
  make ci-operator-config    # determinizes config YAML (sorts keys, normalizes)
  make jobs                  # regenerates prow job configs from ci-operator configs
  ```
  Without this, the PR will fail `ci-operator-config-metadata` and `generated-config` checks.
  Both commands require `podman` (or `docker`) and pull CI tooling images.

## Output Format

Present results as:

```
## Test Recommendations for <PR# or branch>

### Changed Files
- file1.yml
- file2.yml

### Minimum Tests (must pass)
1. `deploy-sno` — covers bastion, inventory, boot-iso changes
2. `deploy-mno` — covers install-cluster changes

### Extra Coverage (recommended)
3. `deploy-cmno` — compact MNO variant for mno-deploy.yml change

### Feature-Specific Tests
4. `deploy-mno-private-bond` — bond logic was modified

### Cross-Repo Notes
(if applicable) New variable `enable_foo` requires openshift/release PR.
```

If no test is needed (docs-only change), say so explicitly.
