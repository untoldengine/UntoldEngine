# USC Scripting Workflow

This document describes the **end-to-end workflow** for developing USC scripts in the Untold Engine.

USC scripts are authored in Xcode. The Untold Editor coordinates assets and playback but does not include a built-in script editor.

---

## Overview

The USC workflow follows a clear sequence:

1. Author scripts
2. Register scripts for generation
3. Build scripts
4. Attach scripts to entities
5. Iterate using hot reload

The editor is the central coordination point for this process, while Xcode is where you author scripts.

---

## Primary Editing Surface

USC scripts are written in Xcode. Use **Scripts: Open in Xcode** to open the Scripts package; the Untold Editor does not provide an in-editor script editor.

Xcode provides:
- Direct access to script source files
- Editing of generation entry points
- Build/run feedback and diagnostics

---

## Script Authoring

Scripts are written as Swift source files using the USC DSL.

Responsibilities:
- Express gameplay behavior
- React to input and engine state
- Remain independent of engine internals

Scripts do not:
- Manage entities directly
- Access low-level engine systems
- Perform rendering or physics logic

---

## Script Registration

All USC scripts are registered through `GenerateScripts.swift`.

This file:
- Defines which scripts are generated
- Acts as a single source of truth for scripting output
- Is edited directly in Xcode

Unregistered scripts are ignored by the engine.

---

## Script Generation and Build

Building and running the GenerateScripts target:
- Runs the USC generation pipeline
- Produces engine-consumable output
- Reports errors and warnings in Xcode

Builds are explicit and controlled.

---

## Runtime Attachment

After a successful build:
- Scripts appear as selectable components
- Scripts can be attached to entities via the Inspector
- Multiple entities may share the same script

The engine controls execution timing.

---

## Hot Reload and Iteration

USC supports rapid iteration:

- Edit script
- Build scripts
- Observe changes immediately

This workflow encourages experimentation and fast feedback.

---

## Design Intent

The USC workflow is intentionally:

- Xcode-first for authoring
- Editor-coordinated for playback
- Explicit
- Predictable
- Easy to debug

It avoids hidden build steps and implicit execution.

---

## Where to Go Next

- Learn USC concepts: **USC → Introduction**
- Explore scripting examples
- Dive into engine integration
