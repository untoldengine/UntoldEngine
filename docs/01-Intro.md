# Untold Engine Documentation

Welcome to the **Untold Engine documentation**.

These docs are the primary reference for working with the Untold Engine ecosystem — whether you are building a game, extending the engine, or contributing to the editor.

---

## What Is Untold Engine?

![untoldengine](images/Editor/EditorMainShot.png)

The Untold Engine strives to be a stable, performant, and developer-friendly 3D engine that empowers creativity, removes friction, and makes game development feel effortless for Apple developers

The Untold Engine is an open-source 3D game engine under active development, designed for macOS, iOS, xrOS platforms. Written in Swift and powered by Metal, its goal is to simplify game creation with a clean, intuitive API. 

While the engine already supports many core systems like rendering, physics, and animation, there’s still much to build and improve.

---

## The Untold Engine Ecosystem

Untold Engine is delivered through three closely related products:

### Untold Engine Studio
A downloadable application that includes:
- The Untold Engine runtime
- The Untold Editor
- Built-in tools for scripting, assets, and scene editing

This is the recommended starting point for most users.

---

### Untold Engine
The core engine runtime.

This is intended for:
- Engine developers
- Contributors
- Advanced users who want to modify or extend engine systems

Installation is performed via the command line.

---

### Untold Editor
The editor application built on top of the engine runtime.

This is intended for:
- Contributors working on editor features
- Developers extending tools and workflows

The editor uses the same runtime as games, ensuring consistent behavior.

---

## Choose Your Path

These docs are organized around **how you intend to use the engine**.

### Game Development
For developers building games using Untold Engine.

You will learn:
- How to create scenes
- How to use USC scripting
- How to work with assets and entities
- How to iterate quickly using the editor

Start here if your goal is to build a game.

---

### Engine Development
For developers who want to understand or extend the engine itself.

You will learn:
- The engine architecture
- ECS and system execution
- Rendering and simulation internals
- How to contribute new engine features

Start here if you want to work on the engine runtime.

---

### Editor Development
For contributors working on the Untold Editor.

You will learn:
- Editor architecture
- Views, tools, and interaction models
- How the editor coordinates with the engine
- How to extend or add editor functionality

Start here if you want to improve the editor.

---

## Getting Started

If you are unsure where to begin:

- New users: **Game Development → Overview**
- Scripting users: **USC → Introduction**
- Contributors: **Engine Development → Architecture**

Each section is designed to stand on its own.

