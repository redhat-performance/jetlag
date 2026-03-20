---
description: Trigger Prow tests on a PR and monitor results
argument-hint: "<PR#> [job-name]"
---

You trigger and monitor Prow CI test jobs on Jetlag PRs.

## Input

- `$ARGUMENTS` — PR number, optionally followed by job name(s)
- Formats:
  - `123 deploy-sno` — trigger `deploy-sno` on jetlag PR #123
  - `123` — auto-detect jobs via test-map logic, then trigger
  - `--release-pr 456 deploy-foo` — trigger on an openshift/release PR

## Parse Arguments

1. Check if `$ARGUMENTS` starts with `--release-pr`:
   - If yes: target repo is `openshift/release`, PR number and job follow
   - If no: target repo is `redhat-performance/jetlag`
2. Extract PR number and optional job name(s)
3. If no job name provided, get the changed files from the PR and apply the test-map logic (from `/jetlag-test-map`) to determine which jobs to run. Present the list and ask the user to confirm which job to trigger first.

## Pre-flight Checks

1. Get HEAD SHA:
   ```
   gh pr view <PR#> --repo <target-repo> --json headRefOid --jq '.headRefOid'
   ```

2. Check for `ok-to-test` label (required for non-org members):
   ```
   gh pr view <PR#> --repo <target-repo> --json labels --jq '.labels[].name'
   ```
   If missing and needed, inform the user that an org member must add `/ok-to-test`.

3. Check current status — a test may already be running or completed:
   ```
   gh api repos/<target-repo>/commits/<SHA>/statuses \
     --jq '[.[] | select(.context | contains("<job>"))] | first | {state, target_url, description}'
   ```
   If a test is already running, ask the user if they want to wait for it or trigger a new one.

## Trigger

**IMPORTANT**: Ask the user for confirmation before triggering. Bare-metal CI jobs are expensive and take 1-2 hours.

Comment on the PR to trigger:
```
gh pr comment <PR#> --repo <target-repo> --body "/test <job-name>"
```

Only trigger ONE job at a time (bare-metal hardware constraint — only one test can run simultaneously).

## Monitor

After triggering, poll for results interactively. Stay active and report progress inline.

**Poll loop**:
1. Wait 2 minutes for the initial status to appear
2. Then poll every 5 minutes:
   ```
   gh api repos/<owner>/<repo>/commits/<SHA>/statuses \
     --jq '[.[] | select(.context | contains("<job>"))] | first | {state, target_url, description, updated_at}'
   ```
3. Report each poll result to the user:
   - `pending` → "Test still running... (elapsed: Xm)"
   - `success` → "Test PASSED"
   - `failure` → "Test FAILED — analyzing..."
   - `error` → "Test ERROR (infra issue)"
4. Timeout after 3 hours — inform user and stop polling

## On Completion

### Success
Report: "Test `<job>` passed on PR #<PR#>."
If there are additional recommended tests from the test-map, ask the user if they want to trigger the next one.

### Failure
1. Extract the Prow URL from the status `target_url`
2. Derive the GCS artifacts path:
   ```
   https://gcsweb-ci.apps.ci.l2s4.p1.openshiftapps.com/gcs/test-platform-results/
   pr-logs/pull/redhat-performance_jetlag/<PR>/
   pull-ci-redhat-performance-jetlag-main-<job>/<run-id>/
   ```
3. Fetch `finished.json` to confirm the failure
4. Fetch `build-log.txt` of the failed step
5. Present a summary:
   ```
   ## Test Failed: <job> on PR #<PR#>

   **Prow URL**: <url>
   **Failed Step**: <step-name>
   **Log excerpt**: (last 50 relevant lines)

   Run `/jetlag-prow-analyze <prow-url>` for detailed analysis.
   ```

### Error (infra)
If the failure is in infrastructure steps (ping, poweroff, BMC access), classify it as an infra flake:
```
Infra error detected (failed in <step>). This is likely a hardware/network flake, not a code issue.
Suggest: `/retest <job>` or wait and retry.
```

## Output

Return a structured result:
```
Job: <job-name>
PR: #<PR#>
Result: success | failure | error | timeout
Prow URL: <url>
Failed Step: <step-name> (if applicable)
Log Excerpt: (if applicable)
Elapsed: <duration>
```
