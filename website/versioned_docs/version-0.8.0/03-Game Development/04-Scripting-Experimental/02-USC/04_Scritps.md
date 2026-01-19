# USC Scripts

This document explains **what a USC script is**, how it fits into the Untold Engine, and the rules that govern its behavior.

It is intended to give you a **clear mental model** before diving into APIs, examples, or workflows.

This page does **not** describe how to write scripts step by step.  
It explains what scripts *represent* and *why they are designed the way they are*.

---

## What Is a USC Script?

A **USC script** is a declarative description of gameplay behavior.

You write scripts in Swift using a constrained, fluent DSL, and the engine executes those scripts at runtime as part of its update loop.

A script expresses **intent**, not implementation details.

Examples of intent:
- Move an entity when input is received
- Apply forces in response to events
- Adjust camera behavior over time

The engine owns *how* those intentions are executed.

---

## Scripts and Entities

USC scripts are **attached to entities**.

- A script always operates in the context of the entity it is attached to
- Scripts do not own entities
- Scripts do not create or destroy entities

Multiple entities may share the same script definition, each with its own execution context and script-local state.

---

## Execution Model

Scripts participate in the engine’s execution model.

Key characteristics:

- Scripts run when their declared events are triggered
- The engine controls execution order and timing
- Scripts do not manage threads or scheduling
- Execution is deterministic and engine-driven

A script never decides *when* it runs — it only declares *what should happen* when it does.

---

## Script Lifecycle

At a high level, a USC script goes through the following lifecycle:

1. Script is authored
2. Script is registered and generated
3. Script is attached to an entity
4. Script becomes active
5. Script executes in response to events
6. Script stops executing when detached or when the entity is destroyed

Lifecycle transitions are managed by the engine.

---

## Events and Entry Points

Scripts are organized around **events**, also called entry points.

Examples include:
- Startup events
- Per-frame updates
- Custom or engine-driven events

Each event defines **when a block of instructions executes**.

Scripts may contain multiple event handlers, each expressing a different behavior.

---

## Script Context

Every script executes with a **context** provided by the engine.

The context gives controlled access to:
- The attached entity’s properties
- Script-defined variables
- Engine-provided values (such as delta time or input state)

Scripts never access engine state directly — all access flows through this context.

---

## State and Variables

Scripts may store local state using variables.

- Variables are scoped to the script instance
- Each entity gets its own variable set
- Variables persist across executions unless reset

Script variables are designed for **lightweight gameplay state**, not long-term data storage.

---

## What Scripts Can Do

USC scripts are designed to express common gameplay behaviors, such as:

- Reading input
- Modifying transforms
- Applying forces or impulses
- Steering entities
- Controlling cameras
- Triggering animations
- Reacting to events

Scripts focus on *what should happen*, not *how systems work internally*.

---

## What Scripts Cannot Do

USC scripts intentionally **cannot**:

- Create or destroy entities
- Access rendering pipelines or GPU resources
- Manage memory
- Spawn threads
- Call arbitrary engine internals
- Control execution order or threading

These constraints are deliberate and central to USC’s design.

---

## Design Intent

USC exists to provide:

- Predictable gameplay behavior
- Clear ownership of state
- Safe boundaries between game logic and engine internals
- Fast iteration and easy debugging

By limiting what scripts can do, the engine remains stable and behavior remains easy to reason about.

---

## Relationship to the API Reference

This document explains **what a script is**.

For detailed information about:
- Available events
- Instructions and commands
- Math operations
- Input handling
- Physics and camera helpers

See **USC → API Reference**.

