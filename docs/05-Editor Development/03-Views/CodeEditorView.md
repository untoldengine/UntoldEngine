# Code Editor View

The **Code Editor View** is the text editing surface for scripts and other source assets in the Untold Editor. USC scripts themselves are authored in Xcode; the editor does not provide a built-in USC script editor.

It presents source files, supports editing workflows, and emits save/build/run intents through the coordination layer without owning compilation or runtime.

This document describes the **architectural role** of the Code Editor View, not how to use it as an end user.

---

## Purpose

The Code Editor View exists to:

- Surface project scripts and source files for editing
- Provide an authoring surface for text assets; USC authoring lives in Xcode and is only surfaced here for viewing/coordination
- Bridge editing to build and run workflows via explicit commands
- Reflect scripting workflow state (open project, build output) in the editor context

It is the link between source assets and scripting workflows, not the runtime itself.

---

## Responsibilities

The Code Editor View is responsible for:

- Displaying and editing text buffers for selected source assets
- Reflecting file metadata (path, dirty state, read-only status)
- Emitting save commands for edited buffers
- Emitting build/run/test commands tied to scripting workflows
- Surfacing diagnostics and build output provided by external services
- Respecting editor mode (Edit vs Play) when enabling edits or execution commands

The Code Editor View does **not** own source storage, compilation, or runtime execution.

---

## What This View Does NOT Do

The Code Editor View intentionally does **not**:

- Interpret or execute USC or other scripts
- Own compilation, packaging, or deployment workflows; it triggers them
- Manage source control operations beyond reflecting status indicators
- Own project discovery or dependency resolution
- Apply engine changes directly; all actions flow through commands
- Decide selection globally; it observes selection/open-file state from shared editor context

If code editor behavior appears to require compilation or runtime ownership, that logic belongs elsewhere.

---

## Data Flow

The Code Editor View participates in the editor data flow as follows:

### Reads
- Source file contents and metadata (path, permissions, timestamps)
- Open-file/session state from the editor
- Build/run status and diagnostics from scripting services
- Editor mode state

### Emits
- Save commands for current buffers
- Build/run/test commands for the active scripting project
- File open/close requests within the editor session
- Selection change requests for symbols or files if shared selection is used

All emitted actions flow through the editor coordination layer.

---

## Interaction With Other Views

The Code Editor View interacts indirectly with other views via shared editor state:

- **Asset Browser**  
  Opens scripts selected in the asset list

- **Scene View / Scene Hierarchy**  
  May reflect selection-driven context (e.g., open script referenced by a component) but does not call views directly

- **Inspector**  
  Consumes scripts as assignable assets; script edits propagate via save and build commands

The Code Editor View does not directly communicate with other views.

---

## Edit Mode vs Play Mode Behavior

### Edit Mode
- Full text editing, save, and build/run commands are enabled
- Diagnostics and build output are surfaced for authoring

### Play Mode
- Editing may be limited or read-only depending on project policy
- Build/run commands that mutate authoring state may be blocked or deferred
- Runtime logs may be surfaced without enabling authoring changes

Mode transitions are handled externally and reflected in the view.

---

## Extension Points

Contributors may extend the Code Editor View by:

- Adding language services (syntax highlighting, completion, diagnostics) via existing plugin hooks
- Integrating advanced navigation (symbol search, references) through shared project metadata
- Surfacing build/test pipelines with richer progress and error reporting
- Enhancing run configurations to emit explicit launch commands

Extensions should integrate through existing command pathways and shared scripting state.

---

## Design Constraints

The Code Editor View is intentionally constrained to:

- Text editing and presentation of scripting-related feedback
- Command emission for save/build/run
- Stateless or minimal local UI state driven by shared data
- No direct compilation, execution, or mutation of engine state

Keeping these boundaries strict ensures predictable scripting workflows and debuggability.

---

## Where to Go Next

- Learn how selection and open-file state work: `Selection`
- Understand command emission: `Editor Coordination Layer`
- Explore scripting pipeline details: `Engine Development → Scripting`
