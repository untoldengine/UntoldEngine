---
id:  contributorguidelines
title: Contributor Guidelines
sidebar_position: 1
---

# Contributing Guidelines

Thank you for your interest in contributing! 
 
The vision for Untold Engine is to continually shape a 3D engine that is **stable, performant and developer-friendly**.
As maintainer, my focus is on **performance, testing, quality control, and API design**.  
Contributors are encouraged to expand features, fix bugs, improve documentation, and enhance usability — always keeping the vision in mind.  

---

## Maintainer Responsibilities  

The Untold Engine is guided by a clear vision: To be a stable, performant, and developer-friendly 3D engine that empowers creativity, removes friction, and makes game development feel effortless.

## Guiding Principles

To achieve this vision, we follow these principles:

- The engine strives to remain stable and crash-free.
- The codebase is backed by unit tests.
- We profile continuously to prevent regressions (visual and performance).
- The API must remain clear and user-friendly.
- We always think about the developer first—removing friction so they can focus on their games.

As the maintainer, my primary focus is to ensure the project stays true to this vision.  

### What I Focus On  
- **Performance** → keeping the renderer and systems lean, efficient, and optimized for Apple hardware.  
- **Testing & Stability** → maintaining a reliable codebase with proper testing practices.  
- **Quality Control** → reviewing PRs for clarity, readability, and adherence to coding standards.  
- **API Design** → ensuring that the engine’s API remains logical, intuitive, and consistent.  

### What Contributors Are Encouraged to Focus On  
- **Features** → adding or improving systems, tools, and workflows.  
- **Bug Fixes** → addressing open issues and fixing edge cases.  
- **Documentation** → clarifying how things work and providing examples.  
- **Editor & Usability** → enhancing the UI, workflows, and overall developer experience.  

### Decision Making  
All contributions are welcome, but acceptance will be guided by the project’s vision and the priorities above.  
PRs that align with clarity, performance, or creativity — while keeping the engine stable and simple — are more likely to be accepted.   

These guidelines aren’t here to block you, but to make sure every contribution keeps the engine stable, clear, and useful for everyone.

## Pull Request Guidelines

- **One feature or bug fix per PR**  
  Each Pull Request should focus on a single feature, bug fix, or documentation improvement.  
  This keeps the history clean and makes it easier to track down issues later.  

- **Commit hygiene**  
  - Keep commits meaningful (avoid "misc changes" or "fix stuff").  
  - Squash commits if needed, but do not mix unrelated features in the same commit.  
  - If your PR touches multiple files, make sure they all relate to the same feature or fix.  

✅ Example:  
- Good: *“Add PhysicsSystem with gravity integration”*  
- Bad: *“Added PhysicsSystem + fixed rendering bug + updated docs”*  

---

## Required Contributions for New System Support

For **new systems or major features**, your PR must include:

- **Unit Tests** → Validate functionality and cover edge cases.  
- **How-To Guide** → A step-by-step markdown guide explaining how to use the system.  

This ensures new features are stable, documented, and accessible to all users.  

👉 Note: For small fixes or incremental features, a How-To is not required.

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

---

## Questions & Discussions

To keep communication clear and accessible for everyone:

- 💡 Use **[GitHub Discussions](https://github.com/untoldengine/UntoldEngine/discussions)** for feature proposals, ideas, or general questions.  
- 🐞 Use **[GitHub Issues](https://github.com/untoldengine/UntoldEngine/issues)** for bugs or concrete tasks that need tracking.  

This way, conversations stay organized, visible to the community, and future contributors can benefit from past discussions.  

---

Thank you for contributing to the Untold Engine! Following these guidelines will ensure that your work aligns with the project's goals and provides value to users.
