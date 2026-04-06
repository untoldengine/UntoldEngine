---
slug: /intro
---

# Untold Engine

Untold Engine is an **open-source 3D engine written in Swift and powered by Metal**, designed for Apple platforms including **macOS, iOS, and visionOS**.

The project focuses on building a **clean, system-driven architecture** with modern rendering, an ECS-based gameplay model, and an extensible asset pipeline.

The engine is under active development and continues to evolve as new systems and workflows are added.

---

## 🎯 Who is this for?

Untold Engine is designed for developers who:

- Want **full control over rendering and systems**
- Prefer working directly with **Swift + Metal**
- Are building **XR, 3D, or visualization applications**
- Need to handle **large scenes, streaming data, or custom pipelines**

This is not a drag-and-drop editor-first engine — it is a **code-driven engine for developers who want to understand and shape the system**.


Creator & Lead Developer:  
http://www.haroldserrano.com

---

# 🚀 Try the Engine Right Now

The fastest way to experience Untold Engine is to run the demo project.

Clone the repository, run the engine and load a USDZ file:

```bash
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine
swift run untolddemo
```

This will:

- Build the engine using **Swift Package Manager**
- Compile the demo project
- Launch the demo so you can see the engine running immediately

No additional setup is required.

---

## 🧱 Core Direction

Untold Engine is being developed with the following goals:

- **Large Scene Rendering**  
  Striving to support LOD, geometry streaming, batching, and memory-aware systems for large datasets

- **XR / visionOS Support**  
  Expanding support for spatial input, AR workflows, and Vision Pro experiences

- **Metal-First Architecture**  
  Keeping the rendering layer close to Metal to maintain performance and control

---

## 🖼 Example Use Cases

Untold Engine aims to support applications such as:

- XR applications (Vision Pro, ARKit-based apps)
- Large-scale scene visualization (cities, archviz, datasets)
- Custom rendering pipelines and experiments
- Simulation tools and interactive 3D systems
