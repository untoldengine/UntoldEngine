# Editor Architecture

This document provides a high-level overview of the **Untold Editor architecture**.

It is intended for contributors who want to understand how the editor is structured before working on specific views, tools, or workflows.

This page focuses on **concepts, responsibilities, and data flow**, not implementation details.

---

## Architectural Goals

The Untold Editor is designed with the following goals:

- **Editor as a client of the engine**  
  The editor uses the same runtime as the game.

- **Explicit data flow**  
  Editor actions translate directly into engine state changes.

- **Minimal editor-only behavior**  
  Play mode mirrors runtime behavior as closely as possible.

- **Composable tools and views**  
  Editor features should be modular and replaceable.

The editor is a tool — not a separate simulation environment.

---

## High-Level Structure

At a conceptual level, the editor is organized into these layers:

Editor UI (Views & Tools)  
↓  
Editor Coordination Layer  
↓  
Engine Runtime  
↓  
Platform & Rendering Backends

The editor does not own the engine — it **drives** it.

---

## Editor as an Engine Client

The Untold Editor runs on top of the same engine runtime used by games.

Key implications:
- Scene data is real engine data
- Systems execute through the same update loop
- Rendering paths are shared
- Bugs reproduced in the editor are runtime-relevant

There is no “fake” editor simulation.

---

## Editor Coordination Layer

Between the UI and the engine sits a thin coordination layer.

This layer is responsible for:
- Translating UI actions into engine operations
- Managing selection state
- Coordinating editor-only modes (Edit vs Play)
- Routing commands between views

It does **not** contain simulation logic.

---

## Views

The editor is composed of **independent views**, each with a focused responsibility.

Typical views include:
- Scene View
- Inspector
- Scene Hierarchy
- Asset Browser
- Code Editor (USC scripts are authored in Xcode; the editor does not include a built-in USC script editor)

Views:
- Observe engine state
- Emit commands
- Do not own core data

This keeps views simple and interchangeable.

---

## Tools and Interaction

Editor tools (selection, transform, manipulation, etc.) are built as:
- Stateless or minimally stateful controllers
- Operating on selected engine entities
- Emitting explicit transform or component changes

Input handling is centralized and routed to active tools.

---

## Scene Editing Model

Scene editing operates directly on engine data:

- Entities and components are real
- Transforms update immediately
- Changes are visible to all views

Editor-only metadata (selection, highlighting, gizmos) is stored separately.

---

## Edit Mode vs Play Mode

The editor supports two primary modes:

### Edit Mode
- Systems that mutate simulation state are paused
- Editor tools manipulate entity state directly
- Scene changes are persistent

### Play Mode
- Full engine update loop runs
- USC scripts execute
- Physics and animation systems are active
- Scene state may be restored on exit

The transition between modes is explicit and controlled.

---

## Asset and Resource Handling

The editor manages assets as references to engine resources.

Responsibilities include:
- Importing external files
- Tracking asset paths
- Updating resource bindings
- Refreshing views when assets change

The engine remains the owner of resource lifetimes.

---

## Relationship to USC

USC scripts are authored in Xcode and managed through the editor but executed by the engine. The editor itself does not host a built-in USC script editor.

The editor:
- Creates script source files
- Triggers script builds
- Attaches generated scripts to entities

The editor does not interpret or execute USC logic.

---

## Design Tradeoffs

The Untold Editor intentionally avoids:

- Duplicating engine logic
- Editor-only simulation paths
- Heavy UI-driven state mutation
- Hidden side effects from tools

These tradeoffs prioritize:
- Consistency with runtime behavior
- Debuggability
- Contributor approachability

---

## Architecture in Practice

This document describes the conceptual structure of the editor.

For implementation details, see:

Editor Development → Architecture → Internals

---

## Where to Go Next

- Learn how views are structured
- Understand editor input and tools
- Explore editor contribution patterns
