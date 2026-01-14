---
description: Fetch and review a GitHub PR
---

You are tasked with reviewing a GitHub Pull Request. Follow these steps:

1. **Fetch PR details**: Use `gh pr view {{arg:1}}` to get PR information (title, description, author, files changed)

2. **Checkout the PR**: Use `gh pr checkout {{arg:1}}` to check out the PR branch locally

3. **Analyze the changes**:
   - Use `gh pr diff {{arg:1}}` to see the full diff
   - Read the modified files to understand the context
   - Pay attention to the PR description and any linked issues

4. **Provide a comprehensive review** covering:
   - **Summary**: Brief overview of what the PR does
   - **Code Quality**: Architecture, patterns, readability, maintainability
   - **Potential Issues**: Bugs, edge cases, security concerns, performance issues
   - **Testing**: Are tests adequate? Are there missing test cases?
   - **Documentation**: Is documentation updated if needed?
   - **Ansible-Specific Checks**:
     - **Idempotency**: Tasks should be idempotent (can be run multiple times safely)
     - **Module Selection**: Use of appropriate Ansible modules (avoid shell/command when native modules exist)
     - **Variable Naming**: Follow consistent naming conventions, proper scoping (group_vars, host_vars, role defaults)
     - **Task Naming**: All tasks have clear, descriptive names
     - **YAML Formatting**: Proper YAML syntax, consistent indentation, use of multi-line strings where appropriate
     - **Handlers**: Proper use of handlers for service restarts and notify/listen patterns
     - **Jinja2 Templates**: Correct usage of filters, tests, and variable references
     - **Error Handling**: Use of failed_when, changed_when, ignore_errors appropriately
     - **Tags**: Meaningful tags for task organization and selective execution
     - **Secrets Management**: No plain-text passwords, proper use of ansible-vault if applicable
     - **Conditionals**: Proper use of when clauses, check for undefined variables
     - **Loops**: Efficient use of loop, with_items, etc.
     - **Role Structure**: Follows standard role directory structure if roles are modified
     - **Deprecations**: No use of deprecated Ansible features or modules
     - **Performance**: Consideration of serial, async, poll for long-running tasks
   - **Suggestions**: Specific, actionable improvements with code examples where helpful

5. **Format your review** in a clear, structured markdown format that's easy to read

Be thorough but constructive. Focus on meaningful feedback that helps improve the code.