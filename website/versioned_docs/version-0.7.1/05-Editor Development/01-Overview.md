---
id:  editoroverview
title: Overview
sidebar_position: 1
---

# Editor Development Overview

This section is for developers who want to **improve or extend the Untold Editor**.

The editor is a separate application built on top of Untold Engine.

---

## What You’ll Work On

In this section, you’ll learn how to:
- Understand the editor architecture
- Add or modify editor views
- Improve workflows and tooling
- Integrate editor features with the engine

Editor development focuses on **usability and tooling**, not gameplay.

---

## Installing the Editor for Development

Working on the editor requires installing Untold Editor via the command line and running it from source.

For editor development, clone this repository:

```bash
git clone https://github.com/untoldengine/UntoldEditor.git
cd UntoldEditor
```
The Editor is a Swift Package with an executable target named UntoldEditor.
It declares a dependency on the Untold Engine package; Xcode/SwiftPM will resolve it automatically.

### Open in Xcode

1. Open Xcode → File ▸ Open → select the Package.swift in this repo
2. Xcode will create a workspace view for the package
3. Choose the UntoldEditor scheme → Run

### Build & run via CLI
If you prefer working with the terminal, you can build and run the Editor as follows: 

```bash
swift build
swift run UntoldEditor
```

### Pinning the Engine Dependency

By default, this repo pins Untold Engine to a released version.
If you want the latest engine changes:

#### Option A — Xcode UI
- In the project navigator: Package Dependencies → UntoldEngine
- Set Dependency Rule to Branch and type develop

#### Option B — Edit Package.swift

```swift
.dependencies = [
    .package(url: "https://github.com/untoldengine/UntoldEngine.git", branch: "develop")
]
```

Then reload packages:

```bash
xcodebuild -resolvePackageDependencies
# or in Xcode: File ▸ Packages ▸ Resolve Package Versions
```


The editor can be developed independently of game projects.

---

## 🕹 Using the Editor

1. **Create / Open a Project** – Use the start screen or File menu  
2. **Set Asset Folder** – Choose an **external** directory for your project’s assets  
3. **Import Assets** – Drag files in or use the Asset Browser “+”  
4. **Build Your Scene** – Create entities, add components, use gizmos to position  
5. **Play Mode** – Toggle to simulate and validate behavior  
6. **Save / Load** – Save project and scene files; reopen later to continue  

> 💡 Why an *external* asset folder?  
> It enables **runtime importing** and iteration without copying everything into the app bundle.


## Editor Architecture

The Untold Editor is structured around:
- Independent views
- Shared engine state
- Explicit data flow between UI and engine
- Minimal magic

Understanding the editor architecture is key before adding features.

You can start with:

> **Editor Development → Architecture**

---

## Editor Views and Interaction

The editor is composed of views such as:
- Scene View
- Inspector
- Asset Browser
- Scene Hierarchy
- Code Editor (note: USC scripts are authored in Xcode; the editor does not include a built-in USC script editor)

Each view is designed to be modular and replaceable.

---

## Who This Section Is Not For

This section is **not** intended for:
- Game developers building gameplay
- Engine developers working on core systems
- Users looking to learn the editor UI

If you want to *use* the editor, see:

> **Game Development → Using the Editor**

