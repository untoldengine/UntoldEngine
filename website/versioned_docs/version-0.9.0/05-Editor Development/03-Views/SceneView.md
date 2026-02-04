# Scene View

The **Scene View** is the primary spatial view in the Untold Editor.

It provides a visual representation of the current scene and allows contributors and tools to interact with entities in world space.

This document describes the **architectural role** of the Scene View, not how to use it as an end user.

---

## Purpose

The Scene View exists to:

- Visualize the current scene state
- Display entities and their transforms
- Provide spatial context for selection and manipulation
- Act as the main interaction surface for world-space tools

It is the bridge between engine data and spatial editor interaction.

---

## Responsibilities

The Scene View is responsible for:

- Rendering a visual representation of the scene
- Displaying editor overlays (selection outlines, gizmos, helpers)
- Receiving world-space input (mouse, keyboard, gestures)
- Emitting commands related to selection and transformation
- Respecting the current editor mode (Edit vs Play)

The Scene View does **not** own scene data.

---

## What This View Does NOT Do

The Scene View intentionally does **not**:

- Own or modify engine state directly
- Perform simulation, physics, or animation updates
- Decide how entities are selected globally
- Execute USC scripts
- Implement rendering pipelines or render passes

If the Scene View appears to require simulation logic, that logic belongs elsewhere.

---

## Data Flow

The Scene View participates in the editor data flow as follows:

### Reads
- Scene graph data
- Entity transforms
- Camera state
- Selection state
- Editor mode state

### Emits
- Selection change requests
- Transform manipulation commands
- Camera navigation commands
- Tool activation signals

All emitted actions flow through the editor coordination layer.

---

## Interaction With Other Views

The Scene View interacts indirectly with other views via shared editor state:

- **Scene Hierarchy**  
  Synchronizes selection changes

- **Inspector**  
  Displays and edits data for selected entities

- **Asset Browser**  
  May initiate drag-and-drop actions into the scene

The Scene View does not directly communicate with other views.

---

## Tools and Manipulation

World-space tools (translate, rotate, scale, etc.) are driven through the Scene View.

Key characteristics:
- Tools operate on selected entities
- Input is routed to the active tool
- Tools emit explicit transform commands
- Visual gizmos are editor-only overlays

The Scene View hosts tool interaction but does not implement tool logic.

---

## Camera Control

The Scene View owns the **editor camera**, which is distinct from game cameras.

Responsibilities include:
- Camera navigation (orbit, pan, zoom)
- Framing selected entities
- Switching camera perspectives

Editor camera state is isolated from runtime camera components.

---

## Edit Mode vs Play Mode Behavior

### Edit Mode
- Scene View allows full manipulation
- Entity transforms are persistent
- Editor overlays and gizmos are visible

### Play Mode
- Scene View observes runtime state
- Manipulation may be limited or disabled
- Runtime cameras may be previewed

Mode transitions are handled externally and reflected in the view.

---

## Extension Points

Contributors may extend the Scene View by:

- Adding new world-space tools
- Introducing new editor overlays
- Customizing camera behavior
- Adding debug visualization layers

Extensions should integrate through existing tool and command pathways.

---

## Design Constraints

The Scene View is intentionally constrained to:

- Visualization
- Input capture
- Command emission

Keeping these boundaries strict ensures:
- Predictable behavior
- Easier debugging
- Cleaner separation of concerns

