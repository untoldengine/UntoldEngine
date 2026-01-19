# Inspector View

The **Inspector View** is the focused property panel for examining and editing the selected entities and components in the Untold Editor.

It presents authoritative component data for the current selection and emits structured changes back through the editor coordination layer.

This document describes the **architectural role** of the Inspector View, not how to use it as an end user.

---

## Purpose

The Inspector View exists to:

- Surface component data for the current selection
- Provide structured editors for component properties
- Validate edits against component rules and modes
- Emit explicit change requests to the coordination layer

It is the bridge between selection state and component-level editing.

---

## Responsibilities

The Inspector View is responsible for:

- Displaying the current selection (single or multi-entity)
- Rendering component sections and property editors
- Showing validation and state (read-only, overridden, default)
- Emitting add/remove component requests
- Emitting property change commands with full context (target entity, component, field, value)
- Reflecting editor mode (Edit vs Play) in allowed operations

The Inspector View does **not** own component data or selection state.

---

## What This View Does NOT Do

The Inspector View intentionally does **not**:

- Manage or decide selection; it only observes it
- Apply engine changes directly; all edits flow through commands
- Run simulation, scripting, or component lifecycle logic
- Own component storage or serialization; it only issues edits
- Own schemas or define component types (it consumes published definitions)
- Manage undo/redo stacks (it emits commands compatible with them)
- Provide asset authoring workflows beyond property-level references

If Inspector behavior appears to require simulation or data ownership, that logic belongs elsewhere.

---

## Data Flow

The Inspector View participates in the editor data flow as follows:

### Reads
- Selection state
- Component definitions and metadata (including editability rules)
- Component instances for selected entities
- Editor mode state
- Validation results and command feedback

### Emits
- Property change commands
- Component add/remove requests
- Component reorder or enable/disable requests (if supported by schema)
- Mode-aware warnings (e.g., attempted edit in Play mode)

All emitted actions flow through the editor coordination layer.

---

## Interaction With Other Views

The Inspector View interacts indirectly with other views via shared editor state:

- **Scene Hierarchy**  
  Mirrors selection changes driven by hierarchy navigation

- **Scene View**  
  Reflects selection changes initiated in world space

- **Asset Browser**  
  Accepts drag-and-drop asset references into component fields

- **Code Editor**  
  Consumes component schemas defined in code; USC authoring occurs in Xcode, not inside the editor; does not depend on editor code directly

The Inspector View does not directly communicate with other views.

---

## Edit Mode vs Play Mode Behavior

### Edit Mode
- Full component editing is enabled
- Changes persist to the authoring state
- Validation prevents invalid component configurations

### Play Mode
- Inspector prioritizes observation; many edits are read-only or limited
- Runtime values may be displayed distinctly from authoring values
- Commands that would mutate persistent data may be blocked or deferred

Mode transitions are handled externally and reflected in the view.

---

## Extension Points

Contributors may extend the Inspector View by:

- Adding custom property drawers for specific field types
- Providing component-specific inspectors with bespoke UI/validation
- Introducing contextual warnings or hints based on selection
- Enhancing multi-edit behavior across heterogeneous selections

Extensions should integrate through existing data binding and command pathways.

---

## Design Constraints

The Inspector View is intentionally constrained to:

- Observation of selection and component state
- Stateless or minimal local UI state
- Deterministic rendering based on shared data
- Command-only mutations; no direct state writes

Keeping these boundaries strict ensures predictable editing and debuggability.

