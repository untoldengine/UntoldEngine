# Contributing Guidelines

I'm excited to have you contribute to the Untold Engine! To maintain consistency and quality, please follow these guidelines when submitting a pull request (PR). Submissions that do not adhere to these guidelines will not be approved.

### Required Contributions for New System Support

When adding new features or systems to the Untold Engine, your PR must include the following:

1. Unit Tests
- Requirement: All new systems must include XCTests to validate their functionality.
- Why: Tests ensure stability and prevent regressions when making future changes.
- Example: Provide unit tests that cover edge cases, typical use cases, and failure scenarios.

2. How-To Guide
- Requirement: Every new system must include a how-to guide explaining its usage.
- Why: This helps users understand how to integrate and utilize the feature effectively.
- Format: Use the structure outlined below to ensure consistency and clarity.

---

### How-To Guide Format

Your guide must follow this structure:

1. Introduction

- Briefly explain the feature and its purpose.
- Describe what problem it solves or what value it adds.

2. Why Use It

- Provide real-world examples or scenarios where the feature is useful.
- Explain the benefits of using the feature in these contexts.

3. Step-by-Step Implementation

- Break down the setup process into clear, actionable steps.
- Include well-commented code snippets for each step.

4. What Happens Behind the Scenes

- Provide technical insights into how the system works internally (if relevant).
- Explain any significant impacts on performance or functionality.

5. Tips and Best Practices

- Share advice for effective usage.
- Highlight common pitfalls and how to avoid them.

6. Running the Feature

- Explain how to test or interact with the feature after setup.

---

### Additional Notes

- Make sure to follow the [versioning guidelines](versioning.md).
- Ensure all code examples are complete, tested, and follow the engine’s coding conventions.
- PRs must be documented in the /Documentation folder, with guides in markdown format.
- Make sure your code follows the [formatting guidelines](Formatting.md).

---
Thank you for contributing to the Untold Engine! Following these guidelines will ensure that your work aligns with the project's goals and provides value to users.
