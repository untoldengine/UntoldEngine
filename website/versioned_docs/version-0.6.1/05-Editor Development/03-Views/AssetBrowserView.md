# Asset Browser View

The **Asset Browser View** is the discovery and selection surface for project assets within the Untold Editor.

It presents filtered asset metadata, supports browsing and search, and emits asset selection or assignment intents through the coordination layer.

This document describes the **architectural role** of the Asset Browser View, not how to use it as an end user.

---

## Purpose

The Asset Browser View exists to:

- Surface the project’s asset library for discovery
- Enable filtering, searching, and grouping of assets
- Provide a control point for selecting assets
- Initiate asset assignment intents (e.g., “assign mesh,” “assign script”) without owning import or load logic

It is the bridge between asset metadata and editor interactions that consume assets.

---

## Responsibilities

The Asset Browser View is responsible for:

- Displaying asset entries with relevant metadata and previews
- Providing search, filter, and organization affordances
- Reflecting shared selection state for assets
- Emitting asset selection changes
- Emitting asset assignment intents to other systems (e.g., drag-and-drop targets) via commands
- Respecting editor mode (Edit vs Play) where assignment is allowed

The Asset Browser View does **not** own asset data or selection state.

---

## What This View Does NOT Do

The Asset Browser View intentionally does **not**:

- Own or manage asset import, processing, or versioning
- Load GPU resources or instantiate runtime objects
- Apply asset assignments directly; it emits intents through the coordination layer
- Manage project file I/O beyond reading metadata exposed by asset services
- Execute scripts or run simulation logic
- Decide selection globally; it only requests changes through shared state

If asset browser behavior appears to require import, loading, or state ownership, that logic belongs elsewhere.

---

## Data Flow

The Asset Browser View participates in the editor data flow as follows:

### Reads
- Asset catalog metadata (names, types, tags, thumbnails, availability)
- Asset selection state
- Editor mode state
- Search/filter parameters provided by shared state or local UI

### Emits
- Asset selection change requests
- Asset assignment intents (e.g., assign to component field, instantiate into scene)
- Folder or collection navigation commands (if supported by asset services)
- Mode-aware warnings when an assignment is not allowed

All emitted actions flow through the editor coordination layer.

---

## Interaction With Other Views

The Asset Browser View interacts indirectly with other views via shared editor state:

- **Scene View / Scene Hierarchy**  
  Receives asset drops or assignment intents to create or replace scene content

- **Inspector**  
  Accepts asset assignments into component fields

- **Code Editor**  
  May reference scripts as assets; USC authoring itself happens in Xcode, not inside the editor

The Asset Browser View does not directly communicate with other views.

---

## Edit Mode vs Play Mode Behavior

### Edit Mode
- Full asset browsing, selection, and assignment intents are available
- Assignments update authoring data through commands

### Play Mode
- Asset browsing remains available; assignments that mutate authoring data may be blocked or limited
- Runtime-safe assignments (if supported) are routed through the same command pathways

Mode transitions are handled externally and reflected in the view.

---

## Extension Points

Contributors may extend the Asset Browser View by:

- Adding advanced filters (tags, dependencies, usage frequency)
- Introducing custom previews or inspectors for specific asset types
- Extending drag-and-drop behaviors for assignment targets
- Adding collection/saved search features backed by shared state

Extensions should integrate through existing asset metadata sources and command pathways.

---

## Design Constraints

The Asset Browser View is intentionally constrained to:

- Visualization of asset metadata and selection
- Command emission for selection and assignment intents
- Stateless or minimal local UI state driven by shared data
- No direct import, loading, or mutation of asset storage

Keeping these boundaries strict ensures predictable asset workflows and debuggability.

---

## Where to Go Next

- Learn how selection works: `Selection`
- Understand command emission: `Editor Coordination Layer`
- Explore asset pipeline details: `Engine Development → Assets`
