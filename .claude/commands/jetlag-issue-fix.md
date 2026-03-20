---
description: Full issue-to-fix-to-test loop for Jetlag
argument-hint: "<issue#>"
---

You are the orchestrator for the Jetlag issue-to-fix-to-test workflow. You drive the full loop from reading an issue to implementing a fix, creating a PR, triggering CI tests, and iterating on failures.

**IMPORTANT**: This workflow has mandatory human gates. NEVER proceed past a gate without explicit user confirmation.

## Input

- `$ARGUMENTS` — GitHub issue number or URL from `redhat-performance/jetlag`

## Phase 1: UNDERSTAND

1. Fetch the issue:
   ```
   gh issue view <number> --repo redhat-performance/jetlag --json title,body,labels,comments
   ```

2. Extract key information:
   - Error messages or tracebacks
   - Cluster type affected (MNO, SNO, VMNO, hybrid)
   - Lab environment (scalelab, performancelab, ibmcloud)
   - Hardware type (r750, r660, r650, r640, etc.)
   - File or role references
   - OCP version or build type
   - Any reproduction steps

3. Explore referenced code paths in the repo:
   - Read the files/roles mentioned in the issue
   - Understand the current behavior and what's expected
   - Check git blame for recent changes that may have caused the issue

4. **HUMAN GATE 1**: Present your analysis to the user:
   ```
   ## Issue #<N> Analysis

   **Title**: <title>
   **Problem**: <one-line summary>
   **Affected**: <cluster type, lab, hardware>
   **Root Cause**: <your assessment>
   **Affected Files**: <list>

   Shall I proceed with planning a fix?
   ```
   WAIT for user confirmation before proceeding.

## Phase 2: PLAN

1. Identify the files to change and what changes are needed
2. Determine which Prow test jobs cover the change (apply test-map logic):
   - Map changed files to test jobs using the mapping from `/jetlag-test-map`
   - Check for feature modifiers (bond, public_vlan, hybrid, vmno)
   - Check for cross-repo needs (new variables)

3. **HUMAN GATE 2**: Present the fix plan:
   ```
   ## Fix Plan for Issue #<N>

   ### Code Changes
   1. `<file>`: <description of change>
   2. `<file>`: <description of change>

   ### Test Plan
   - Minimum: `deploy-sno`
   - Extra: `deploy-mno`
   - Cross-repo: <yes/no>

   ### Branch
   fix/issue-<N>-<short-desc>

   Shall I implement this fix?
   ```
   WAIT for user confirmation before proceeding.

## Phase 3: IMPLEMENT

1. Create a branch:
   ```
   git checkout -b fix/issue-<N>-<short-desc> main
   ```

2. Make the code changes as planned

3. Commit:
   ```
   git add <specific files>
   git commit -m "<description>

   Fixes #<N>

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
   ```

4. Push:
   ```
   git push -u origin fix/issue-<N>-<short-desc>
   ```

5. Create PR:
   ```
   gh pr create --repo redhat-performance/jetlag \
     --title "<concise title>" \
     --body "## Summary
   <description of the fix>

   Fixes #<N>

   ## Test Plan
   - [ ] `<job1>` — <why this test>
   - [ ] `<job2>` — <why this test>

   ## Changes
   <bullet list of changes>
   "
   ```

## Phase 4: TEST

**HUMAN GATE 3**: Before triggering any test, confirm with the user:
```
PR #<PR#> created. Ready to trigger tests.

Recommended test order:
1. `deploy-sno` (fastest, covers core changes)
2. `deploy-mno` (if applicable)

Trigger `deploy-sno` now? (bare-metal CI, ~1-2 hours)
```
WAIT for user confirmation.

### Standard Flow (existing test covers the change)
1. Trigger the test:
   ```
   gh pr comment <PR#> --repo redhat-performance/jetlag --body "/test <job-name>"
   ```
2. Poll for results (every 5 minutes, 3-hour timeout):
   ```
   gh api repos/redhat-performance/jetlag/commits/<SHA>/statuses \
     --jq '[.[] | select(.context | contains("<job>"))] | first | {state, target_url, description}'
   ```
3. Report progress inline to the user

### Cross-Repo Flow (new feature needs test job changes)
If the test-map flagged cross-repo needs:
1. Create the Jetlag PR first (Phase 3 above)
2. Inform the user about the cross-repo requirement:
   ```
   This change requires a companion PR in openshift/release to add/modify a test job.

   Key files to modify:
   - ci-operator/config/redhat-performance/jetlag/redhat-performance-jetlag-main.yaml
   - ci-operator/step-registry/openshift-qe/installer/bm/deploy/openshift-qe-installer-bm-deploy-ref.yaml
   - ci-operator/step-registry/openshift-qe/installer/bm/deploy/openshift-qe-installer-bm-deploy-commands.sh

   The companion PR should set:
     JETLAG_PR: "<jetlag-PR-number>"
     JETLAG_LATEST: "true"

   Shall I draft the openshift/release changes?
   ```
3. If user confirms, create the companion PR in openshift/release:
   - Clone upstream: `git clone --depth=1 --branch=main https://github.com/openshift/release.git`
   - Add user's fork as remote: `git remote add fork git@github.com:<user>/release.git`
   - Make changes on a new branch
   - **CRITICAL**: Before committing, run the required generators from the repo root:
     ```
     make ci-operator-config    # determinizes ci-operator config YAML (sorts keys, normalizes)
     make jobs                  # regenerates prow job configs from ci-operator configs
     ```
     These generate/update files in `ci-operator/jobs/` and normalize `ci-operator/config/`.
     The PR will fail `ci-operator-config-metadata` and `generated-config` checks without this.
   - Commit all changes (including generated files), push to fork, create PR against openshift/release
4. Trigger tests from the openshift/release PR
5. After the Jetlag PR merges, remind the user to update the openshift/release PR to remove `JETLAG_PR`

## Phase 5: EVALUATE

On test completion:

### Pass
- Update the PR body to check off the passed test
- If more tests are recommended, ask user about triggering the next one
- When all tests pass:
  ```
  All tests passed for PR #<PR#>!

  Results:
  - deploy-sno: PASSED
  - deploy-mno: PASSED

  The PR is ready for review. A maintainer can /lgtm and /approve.
  (I will NOT merge — that's for humans.)
  ```

### Infra Error
If the failure is in infrastructure steps (ping, poweroff, BMC):
```
Infra error detected in `<step>`. This is a hardware/network flake, not a code issue.
Recommend: `/retest <job>`
```
Do NOT count infra errors toward the 3-iteration limit.

### Code Failure
**HUMAN GATE 4**: Present failure analysis and proposed revision:
```
## Test Failed: <job>

### Root Cause
<analysis from log examination>

### Failed Task
<role>/<task> on <host>: <error>

### Proposed Fix
<description of what to change>

### Iteration
This is attempt <N>/3.

Shall I push a fix and re-test?
```
WAIT for user confirmation.

If confirmed:
1. Make the fix
2. Add a new commit (NEVER force-push or amend)
3. Push
4. Re-trigger the test
5. Resume polling

### Escalation
After 3 failed iterations:
```
3 attempts have failed. Escalating to human review.

Iteration history:
1. <what was tried> → <what failed>
2. <what was tried> → <what failed>
3. <what was tried> → <what failed>

The PR remains open for manual investigation.
```

## Safety Rails

- **Max 3 fix iterations** before escalating to human
- **Max 3-hour timeout** per test job
- **Never trigger >1 test simultaneously** (bare-metal hardware constraint)
- **Always add new commits** — never force-push, never amend published commits
- **Always reference issue number** in commits and PR body
- **NEVER merge** — present results and let humans /lgtm + /approve
- **NEVER skip human gates** — always wait for explicit confirmation
