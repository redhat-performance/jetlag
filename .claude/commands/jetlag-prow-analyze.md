---
description: Analyze failed Prow job logs for Jetlag
argument-hint: "<prow-url>"
---

You analyze failed Prow CI job logs for Jetlag deployments, identifying root causes and suggesting fixes.

## Input

- `$ARGUMENTS` — Prow job URL
- Example: `https://prow.ci.openshift.org/view/gs/test-platform-results/pr-logs/pull/redhat-performance_jetlag/123/pull-ci-redhat-performance-jetlag-main-deploy-sno/1234567890`

## Step 1: Parse the URL

Extract from the Prow URL:
- PR number (from path)
- Job name (e.g., `deploy-sno`, `deploy-mno`)
- Run ID (build number)
- GCS base path

Construct the GCS web URL:
```
https://gcsweb-ci.apps.ci.l2s4.p1.openshiftapps.com/gcs/test-platform-results/
pr-logs/pull/redhat-performance_jetlag/<PR>/
pull-ci-redhat-performance-jetlag-main-<job>/<run-id>/
```

## Step 2: Fetch Artifacts

Use WebFetch to download key artifacts from GCS:

1. **`finished.json`** — overall result and timestamp
2. **`build-log.txt`** — full build log (may be large; fetch and scan for failures)
3. **Step-level logs** — check `artifacts/<step-name>/build-log.txt` for individual steps:
   - `openshift-qe-installer-bm-deploy` — the main deployment step
   - Other steps as indicated by `finished.json`

If the URL is for a periodic/batch job (not a PR), adjust the GCS path accordingly (use `logs/` instead of `pr-logs/pull/`).

## Step 3: Identify Failure Point

Scan `build-log.txt` for these Ansible failure patterns (in priority order):

1. **`fatal: [hostname]: FAILED!`** → Extract:
   - The task name (from `TASK [role : task name]` line above)
   - The error `msg:` field
   - The host that failed

2. **`PLAY RECAP`** with `failed>0` → Which host(s) failed and at which play

3. **`MODULE FAILURE`** → Module-level crash with traceback

4. **`ERROR!`** → Ansible-level errors (syntax, undefined variable, unreachable host)

5. **Non-Ansible failures**:
   - `error: `  or `Error:` lines
   - Python tracebacks
   - Shell command failures (exit code != 0)

## Step 4: Correlate with PR Changes

If this is a PR job:
1. Get the PR's changed files: `gh pr diff <PR#> --name-only --repo redhat-performance/jetlag`
2. Compare the failed task/role against the changed files
3. Classify:
   - **Changed code failure**: The failed task/role is in files modified by the PR → likely our bug
   - **Unrelated failure**: The failed task/role is NOT in files modified by the PR → pre-existing issue or infra
   - **Infra failure**: Failure in hardware/network operations (ping, poweroff, BMC reset, IPMI) → infra flake

## Step 5: Classify and Recommend

### Classification Categories

**Code Bug** (failure in changed code):
- Identify the exact task and error
- Show the relevant code from the PR diff
- Suggest a specific fix
- Recommend: push fix commit, re-test

**Pre-existing Bug** (failure in unchanged code):
- Note that this failure is NOT caused by the PR
- Check if there's a known issue for this failure
- Recommend: file separate issue, `/retest` to confirm it's unrelated

**Infra Flake** (hardware/network):
Indicators:
- Failed task involves: `ping`, `poweroff`, `ipmitool`, `racadm`, `badfish`, BMC operations
- Error messages: `unreachable`, `timed out`, `connection refused`, `No route to host`
- Failure in `boot-iso` role during virtual media attachment
Recommend: `/retest <job>` — don't count as code failure

**Timeout**:
- Cluster install exceeded time limit
- Hosts not discovered within timeout
- Recommend: check if PR introduces slower operations, or `/retest`

**Configuration Error**:
- Undefined variable, missing file, bad YAML syntax
- Usually a code bug in the PR
- Recommend: fix the syntax/variable issue

## Step 6: Leverage Existing Prow Skills

For deeper analysis, delegate to existing prow-job skills where applicable:
- Use `/prow-job:analyze-test-failure` patterns for structured test failure analysis
- Use `/prow-job:extract-must-gather` patterns if must-gather artifacts are available
- Use `/prow-job:analyze-resource` patterns for resource lifecycle issues

## Output Format

Present the analysis as:

```
## Prow Job Failure Analysis

**Job**: <job-name>
**PR**: #<PR#>
**Run**: <run-id>
**Result**: FAILED

### Root Cause
<Classification>: <one-line summary>

### Failed Task
- **Role**: <role-name>
- **Task**: <task-name>
- **Host**: <hostname>
- **Error**: <error message>

### Log Excerpt
(relevant 20-30 lines around the failure)

### Correlation with PR
<Whether the failure is in changed code, unrelated code, or infra>

### Recommendation
<Specific action: fix code, retest, file issue, etc.>
<If code fix: show the suggested change>
```
