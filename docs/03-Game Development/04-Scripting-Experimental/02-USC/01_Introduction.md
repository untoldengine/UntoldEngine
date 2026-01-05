---
id: usc-scripting-introducction
title: Introduction
sidebar_label: Introduction
sidebar_position: 1
---

# Introduction to USC

USC (Untold Script Core) is the scripting system used to define **gameplay behavior** in Untold Engine.

USC is designed to be:
- Explicit
- Predictable
- Easy to read and reason about

It focuses on *what your game does*, not how the engine is implemented.

---

## What USC Is

USC is a **script-based API** that allows you to attach behavior to entities.

You use USC to:
- Respond to input
- Move entities
- Control cameras
- Apply forces
- Drive simple gameplay logic

USC scripts describe *behavior over time*.

---

## What USC Is Not

USC is **not**:
- A general-purpose programming language
- A replacement for engine code
- A system for complex algorithms or heavy math

If you need low-level control or complex systems, those belong in the engine itself.

USC intentionally keeps the surface area small.

---

## Why USC Exists

Traditional game engines often expose:
- Large, complex APIs
- Implicit behavior
- Hidden update order

USC takes a different approach.

It is designed so that:
- Scripts read top-to-bottom
- Behavior is explicit
- There is no hidden execution magic

This makes gameplay logic easier to understand, debug, and maintain.

---

## How USC Fits into Untold Engine

USC sits **above the engine** and **below the editor**.

- The engine provides systems and data
- USC expresses gameplay intent
- The editor helps you attach and manage scripts

USC does not replace the engine — it builds on top of it.

---

## The Script Lifecycle

A USC script runs as part of the engine update loop.

At a high level:
1. The engine updates input
2. USC scripts are evaluated
3. The engine applies the results

Scripts are evaluated every frame while the game is running.

You do not manually manage update loops.

---

## Working with Entities

USC scripts operate on **entities**.

A script is attached to an entity and can:
- Read entity state
- Modify transforms
- Interact with components
- Respond to input

Scripts do not create entities or systems — they control behavior.

---

## Example Use Cases

USC is ideal for:
- Player movement
- Camera follow logic
- Simple physics interaction
- Trigger-based events
- Prototyping gameplay ideas

If something feels *game-specific*, it likely belongs in USC.

---

## Design Philosophy

USC follows a few guiding principles:

- **Explicit over implicit**  
  No hidden behavior.

- **Readable over clever**  
  Scripts should be easy to understand at a glance.

- **Stable over flexible**  
  Fewer features, fewer surprises.

These principles are intentional.

---

## Where to Go Next

- Build your first script: USC → Quick Start

If you’re new to Untold Engine, USC is the best place to start.

