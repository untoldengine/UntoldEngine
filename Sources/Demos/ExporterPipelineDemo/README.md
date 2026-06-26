# Exporter Pipeline Demo

Focused demo for the exported-asset runtime path.

Run it from the repository root:

```bash
swift run exporterpipelinedemo
```

What it demonstrates:

- setting the asset base path with `setEngine(.assetBasePath(...))`
- loading exported `.untold` models with `setEntityMeshAsync`
- loading exported `.untold` animation clips with `setEntityAnimations`
- switching animation clips with `changeAnimation`
- checking whether sibling `*.validation.json` files exist
- showing basic validation metadata: asset name, mesh count, vertex totals, and index totals

This demo does not invoke Blender or export files. It shows the runtime side of
the pipeline after assets have already been exported.
