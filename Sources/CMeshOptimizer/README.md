# CMeshOptimizer

Part of [meshoptimizer](https://github.com/zeux/meshoptimizer) 1.3 (tag `v1.3`), by Arseny Kapoulkine, under the MIT License (see `LICENSE.md`). The files are unmodified copies:

- `include/meshoptimizer.h` is `src/meshoptimizer.h`.
- The `.cpp` files are those of `src/` that the engine uses: the simplifier, the index generator, the vertex cache and vertex fetch optimizers, and the allocator they share. The header declares the whole library; a function of a file that is not here does not link.

The `UntoldEngineMeshCook` module calls the C API from Swift (`import CMeshOptimizer`); no C++ interoperability is needed. It is used by the asset cook, not by the renderer: `UntoldMeshLODCooker` builds the automatic LOD chain of a cooked model with the simplifier.

Only `UntoldEngineMeshCook` imports this module. `UntoldEngine` must not: code that is compiled against a built `UntoldEngine` module without SwiftPM (the editor compiles a project's components that way) would then need this library's module map too, and fail with "missing required module 'CMeshOptimizer'".

## Updating

Replace the files with those of the new tag and update the version above. Add a file of `src/` when the engine starts to use it. Do not edit the files here: local changes would be lost on the next update.
