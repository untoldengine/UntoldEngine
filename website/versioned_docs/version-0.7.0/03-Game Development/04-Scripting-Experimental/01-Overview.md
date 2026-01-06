# Overview

⚠️ **EXPERIMENTAL FEATURE**

This section documents the **UntoldEngine Scripting (USC)** language - an experimental scripting system that is **currently in development**.

---

## Current Status

USC scripting is in **early experimental phases** and is **not recommended for production use**.

For game development, we strongly recommend using **Swift** and **Xcode** (see parent section: [Game Development Overview](../01-Overview.md)).

---

## What is USC?

USC (Untold Scripting Language) is a custom scripting language designed for the UntoldEngine. It aims to provide:

- Simple C-like syntax
- Entity-component scripting
- Scene-based game logic

However, the language is still evolving, and **its future direction is under evaluation**.

---

## Why USC?

Originally, USC was designed to provide:

1. **Lower barrier to entry** - Simpler syntax than Swift
2. **Scene-embedded scripts** - Scripts attached to entities in the editor
3. **Hot-reload** - Faster iteration for non-compiled changes

However, **Swift + Xcode** has proven to be more practical for most use cases:

- Mature tooling (debugging, profiling, autocomplete)
- Type safety and compile-time errors
- Familiar to Apple platform developers
- Better performance

---

## Should You Use USC?

**No, not yet.** Here's why:

❌ **Incomplete** - Many features are missing or unstable  
❌ **Underdocumented** - Documentation is sparse and may be outdated  
❌ **Limited tooling** - No debugger, no IDE support  
❌ **Breaking changes** - Syntax and behavior may change without notice  
❌ **Unoptimized** - Performance is not production-ready

Use **Swift** for all game development until USC reaches a stable release.

---

## When Will USC Be Ready?

USC is in **exploratory development**. We are evaluating:

- Whether USC provides enough value over Swift
- What the ideal syntax and feature set should be
- How to integrate it seamlessly with Xcode workflows

There is **no timeline** for USC becoming production-ready.

---

## Exploring USC Anyway?

If you want to experiment with USC despite the warnings:

1. Read the **[USC Language Reference](./02-USC/01_Introduction.md)**
2. Try the **[USC Tutorials](./03-Tutorials/00_HelloWorld.md)**
3. Understand that **nothing is guaranteed to work**

Do NOT use USC for:
- Production games
- Serious projects
- Teaching materials
- Anything you want to maintain long-term

---

## Feedback

If you experiment with USC, we welcome feedback:

- What do you like about it?
- What frustrates you?
- Does it solve problems Swift doesn't?
- Would you use it if it were stable?

Your feedback helps us decide USC's future direction.

---

