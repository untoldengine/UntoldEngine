# Copilot Code Review Instructions

When reviewing pull requests for this repository:

- Focus on **clarity, maintainability, and consistency** with Swift naming conventions.
- Look out for **duplicate file names** across modules (e.g., Core vs Editor) that could confuse contributors.
- Pay special attention to **unit tests**:
  - Check that new functionality is covered by tests where it makes sense.
  - Flag missing or incomplete tests for critical systems (e.g., rendering, ECS, physics).
  - Suggest improvements for test readability, coverage, and clarity.
- Suggest improvements for **documentation and comments** where the intent of code is not obvious.
- Identify potential **performance bottlenecks**, especially in rendering or compute-heavy code.
- Check for **error handling**: guard statements, meaningful fallback behavior, crash prevention.
- Avoid being overly nitpicky — only raise issues that impact readability, maintainability, testability, or functionality.
- Do not enforce style rules — SwiftFormat is already run automatically. Only highlight when style issues affect readability.
- If something is unclear, ask for explanation rather than rejecting the PR.
- Verify that **all source files and Metal shader files** include the proper copyright and license notice at the very top:
  ```swift
  //  Copyright Untold Engine Studios
  //  Licensed under the GNU LGPL v3.0 or later.
  //  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
  ```

Final decision always rests with human maintainers; Copilot is here to provide helpful suggestions.

