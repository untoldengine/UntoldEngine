# Editor Views Overview

This section documents the **views that make up the Untold Editor**.

It is intended for contributors who want to understand how editor views are structured, how they interact with the engine, and how they coordinate with each other.

This is **not** user documentation.  
It does not explain how to *use* the editor — only how it is built.

---

## What Is a View?

A **View** is a UI surface that:
- Observes engine and editor state
- Presents that state visually
- Emits explicit commands in response to user input

Views do **not** own core data.

They are clients of the editor and engine systems.

---

## Responsibilities of a View

Every editor view follows the same core responsibilities:

- Render information derived from engine or editor state
- React to user input (mouse, keyboard, gestures)
- Emit commands to the editor coordination layer
- Stay stateless or minimally stateful

A view should be easy to reason about in isolation.

---

## What Views Do NOT Do

Views intentionally do **not**:

- Own or mutate engine state directly
- Contain simulation logic
- Manage entity lifetimes
- Execute USC scripts
- Perform rendering or physics work themselves

If a view feels like it needs to “do logic,” that logic likely belongs elsewhere.

---

## Data Flow Model

All views participate in a shared data flow model:

Engine Runtime  
↓  
Editor Coordination Layer  
↓  
Editor Views  
↓  
User Input  
↓  
Editor Commands  
↓  
Engine Runtime  

Key characteristics:
- Data flows downward
- Commands flow upward
- Views never bypass the coordination layer

This keeps behavior predictable and debuggable.

---

## Selection as Shared State

Selection is a cross-view concern.

- Views may observe the current selection
- Views may request selection changes
- No single view owns selection state

This allows multiple views to remain decoupled while staying synchronized.

---

## View Independence

Views are designed to be independent and replaceable.

This means:
- Views do not directly call each other
- Communication happens through shared editor state
- Views can be added, removed, or replaced without breaking others

This is a deliberate architectural decision.

---

## Editor Modes and Views

Views must respect the editor’s active mode.

### Edit Mode
- Views manipulate persistent scene data
- Simulation systems are paused
- Tools operate directly on entity state

### Play Mode
- Views observe runtime state
- Simulation systems are active
- Editing is limited or disabled

Views should not decide mode behavior — they respond to it.

---

## Common View Patterns

While views are independent, many follow similar patterns:

- Scene-oriented views
- Inspection views
- Asset-oriented views
- Code-oriented views

Each category emphasizes different interactions but follows the same architectural rules.

---

## Extending or Adding a View

When adding a new view:

1. Define the view’s purpose
2. Identify the data it observes
3. Identify the commands it emits
4. Ensure it does not own core state
5. Integrate it through the coordination layer

If a new view requires engine changes, document those explicitly.

---

## View Documentation Structure

Each individual view document follows this structure:

- Purpose
- Responsibilities
- What This View Does NOT Do
- Data Flow
- Interaction With Other Views
- Extension Points

This keeps documentation consistent and easy to scan.

---

## Available Views

The following views are documented in this section:

- Scene View
- Inspector
- Scene Hierarchy
- Asset Browser
- Code Editor (USC scripts are authored in Xcode; the editor does not include a built-in USC script editor)

---
