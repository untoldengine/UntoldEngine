# Scene Hierarchy View

The **Scene Hierarchy View** presents the scene graph as an ordered list/tree of entities and is the primary control surface for selection and hierarchy manipulation.

It exposes parent/child relationships conceptually and emits structured commands for selection, reparenting, ordering, and basic entity lifecycle actions.

This document describes the **architectural role** of the Scene Hierarchy View, not how to use it as an end user.

---

## Purpose

The Scene Hierarchy View exists to:

- Visualize the scene graph and entity ordering
- Provide a clear control point for selecting entities
- Enable conceptual hierarchy edits (parenting, unparenting, reordering)
- Initiate entity lifecycle actions (create, duplicate, delete) through commands

It is the bridge between the scene graph model and selection-centric editing.

---

## Responsibilities

The Scene Hierarchy View is responsible for:

- Displaying the scene graph structure and entity ordering
- Reflecting shared selection state and allowing selection changes
- Emitting hierarchy edit commands (reparent, reorder, toggle visibility/activation)
- Emitting entity lifecycle requests (create, duplicate, delete) via commands
- Respecting editor mode (Edit vs Play) when enabling hierarchy edits

The Scene Hierarchy View does **not** own scene data or selection state.

---

## What This View Does NOT Do

The Scene Hierarchy View intentionally does **not**:

- Compute transforms or resolve world/local matrices
- Maintain or persist the scene graph; it only visualizes and issues commands
- Perform simulation, physics, or animation updates
- Decide selection globally; it requests changes through shared state
- Apply engine changes directly; all edits flow through the coordination layer
- Execute scripting or component logic

If hierarchy behavior appears to require graph ownership or simulation, that logic belongs elsewhere.

---

## Data Flow

The Scene Hierarchy View participates in the editor data flow as follows:

### Reads
- Scene graph structure (entities, parent/child links, ordering)
- Entity metadata needed for display (names, icons, state flags)
- Selection state
- Editor mode state

### Emits
- Selection change requests
- Reparent and reorder commands
- Visibility/activation toggle commands (if exposed)
- Entity lifecycle requests (create, duplicate, delete)

All emitted actions flow through the editor coordination layer.

---

## Interaction With Other Views

The Scene Hierarchy View interacts indirectly with other views via shared editor state:

- **Scene View**  
  Synchronizes selection changes between hierarchy and world-space interaction

- **Inspector**  
  Displays and edits data for entities selected in the hierarchy

- **Asset Browser**  
  May support drag-and-drop of assets to instantiate entities or assign references

The Scene Hierarchy View does not directly communicate with other views.

---

## Edit Mode vs Play Mode Behavior

### Edit Mode
- Full hierarchy editing (reparent, reorder, lifecycle actions) is available
- Selection changes drive authoring-state inspection

### Play Mode
- Hierarchy is primarily observational; destructive edits may be blocked or limited
- Selection may reflect runtime entities without persisting authoring changes

Mode transitions are handled externally and reflected in the view.

---

## Extension Points

Contributors may extend the Scene Hierarchy View by:

- Adding filters, search, or grouping affordances
- Introducing custom badges or state indicators derived from metadata
- Extending drag-and-drop behaviors for entity or asset interactions
- Providing bulk operations that emit explicit hierarchy commands

Extensions should integrate through existing command pathways and shared state.

---

## Design Constraints

The Scene Hierarchy View is intentionally constrained to:

- Visualization of the scene graph and selection state
- Command emission for hierarchy and lifecycle edits
- Stateless or minimal local UI state driven by shared data
- No direct mutation of engine or editor core data

Keeping these boundaries strict ensures predictable editing and debuggability.

