---
id: engine-architecture overview
title: Architecture Overview
sidebar_position: 1
---

# Engine Architecture

This document describes the **high-level architecture** of Untold Engine.

It is intended for developers who want to understand how the engine is structured *before* working on individual subsystems such as rendering, physics, or scripting.

This page focuses on **concepts and responsibilities**, not file layouts or implementation details.

---

## Architectural Philosophy

Untold Engine is designed with a small set of guiding principles:

- **Clarity over abstraction**  
  Systems should be understandable without deep indirection.

- **Explicit execution order**  
  Engine behavior is deterministic and visible.

- **Data-oriented design**  
  Data and behavior are separated cleanly.

- **Composable systems**  
  New systems can be added without destabilizing existing ones.

The architecture favors *learnability and debuggability* over convenience shortcuts.

---

## High-Level Structure

At a conceptual level, Untold Engine is organized into the following layers:

Gameplay (USC Scripts)  
↓  
Engine Systems  
↓  
Core Runtime  
↓  
Platform & Rendering Backends

Each layer has a single responsibility and communicates downward through well-defined interfaces.

---

## Core Runtime

The **core runtime** is responsible for:

- Entity and component storage
- System registration and ordering
- Scene lifecycle management
- Global engine state
- Frame orchestration

The runtime does **not** contain gameplay logic, editor logic, or platform-specific behavior.

Its role is to provide a **stable execution environment** for all systems.

---

## Entity–Component–System (ECS)

Untold Engine uses an **Entity–Component–System (ECS)** architecture.

### Entities
- Lightweight identifiers
- Contain no data or behavior
- Used to associate components

### Components
- Plain data containers
- Represent state (transform, physics, rendering, scripting, etc.)
- Do not contain logic

### Systems
- Contain all behavior
- Operate on entities matching specific component sets
- Are executed in an explicit order

This separation keeps systems focused and minimizes hidden dependencies.

---

## System Execution Model

Systems are executed as part of a well-defined update flow.

A simplified frame looks like this:

1. Input collection
2. Simulation and gameplay systems
3. USC script evaluation
4. Physics integration
5. Culling and render preparation
6. Rendering and presentation

There is no implicit or callback-driven execution.

Each system declares:
- When it runs
- What data it reads
- What data it writes

---

## Rendering Architecture

Rendering in Untold Engine is **explicit and staged**.

Key characteristics:
- Clear separation between simulation and rendering
- Explicit render passes
- Minimal global render state
- Platform-specific backends hidden behind a thin abstraction

Rendering is treated as a system, not a special case.

---

## Platform Abstraction

Untold Engine supports multiple platforms through **thin platform layers**.

These layers handle:
- Window and surface management
- Input sources
- Graphics API integration
- Platform lifecycle events

The core engine remains platform-agnostic.

---

## USC Integration

USC (Untold Script Core) is layered on top of the engine.

- The engine owns the update loop
- USC expresses gameplay intent
- Scripts interact with engine state through a constrained API

USC does not bypass engine systems.

This ensures predictable behavior and keeps ownership of state clear.

---

## Editor Relationship

The Untold Editor is built **on top of the same engine runtime** used by games.

- Editor features are implemented as engine clients
- Editor-only systems are isolated
- Play mode uses the same execution path as runtime builds

This minimizes editor-only behavior and keeps debugging consistent.

---

## Design Tradeoffs

Untold Engine intentionally avoids:

- Hidden execution order
- Large global managers
- Overly generic abstractions
- Implicit engine magic

These tradeoffs prioritize:
- Predictability
- Debuggability
- Long-term maintainability

---

## Architecture in Practice

This document provides the conceptual overview.

For implementation-level details, see:

Engine Development → Architecture → Engine internals

