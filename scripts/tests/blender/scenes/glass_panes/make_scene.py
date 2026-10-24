# The glass reference scene: six panes of the kinds of glass found in architectural and vehicle
# models, in front of a striped wall, each with a solid object behind it, and the camera of the
# reference view. The stripes texture is generated and packed into the file.
#
#   blender --background --factory-startup --python scripts/tests/blender/scenes/glass_panes/make_scene.py -- out/glass_panes.blend
#
# Then render_reference.py renders the Blender reference of the same view, and the exporter cooks
# the file for the engine. README.md in this folder has the steps.
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
folder = os.path.dirname(out)
os.makedirs(folder, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# The view of the reference image (render_reference.py uses the same eye, target and field of view).
EYE = Vector((-1.6, -8.2, 1.7))
TARGET = Vector((0.1, 0.6, 0.95))
FOV_Y = 40.0


def principled(name, base, metallic=0.0, roughness=0.5, transmission=0.0, ior=1.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")
    p.inputs["Base Color"].default_value = (*base, 1.0)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = roughness
    p.inputs["Transmission Weight"].default_value = transmission
    p.inputs["IOR"].default_value = ior
    return m, p


def box(name, size, location, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


# The wall: vertical stripes of color, from an image so that the exporter carries it.
width, height = 1024, 256
stripes = np.zeros((height, width, 4), np.float32)
colors = [(0.85, 0.85, 0.85), (0.8, 0.1, 0.1), (0.9, 0.75, 0.1), (0.1, 0.55, 0.2), (0.1, 0.3, 0.8), (0.05, 0.05, 0.05)]
count = 24
for i in range(count):
    stripes[:, i * width // count:(i + 1) * width // count, :3] = colors[i % len(colors)]
stripes[..., 3] = 1.0
image = bpy.data.images.new("stripes", width, height, alpha=False)
image.pixels.foreach_set(stripes.ravel())
image.filepath_raw = os.path.join(folder, "stripes.png")
image.file_format = "PNG"
image.save()
image = bpy.data.images.load(os.path.join(folder, "stripes.png"))
wall_material, wall_bsdf = principled("Wall", (1, 1, 1), roughness=0.9)
texture = wall_material.node_tree.nodes.new("ShaderNodeTexImage")
texture.image = image
wall_material.node_tree.links.new(texture.outputs["Color"], wall_bsdf.inputs["Base Color"])
bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, 3.0, 1.5), rotation=(1.5708, 0.0, 0.0))
wall = bpy.context.active_object
wall.name = "Wall"
wall.scale = (14.0, 3.0, 1.0)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
wall.data.materials.append(wall_material)

floor_material, _ = principled("Floor", (0.35, 0.35, 0.35), roughness=0.8)
bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, 0.0, 0.0))
floor = bpy.context.active_object
floor.name = "Floor"
floor.scale = (14.0, 12.0, 1.0)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
floor.data.materials.append(floor_material)

# The panes, by the kind of glass each stands for: base color, metallic, roughness, transmission, IOR.
panes = [
    ("Clear window", (0.911, 0.966, 0.96), 0.0, 0.04, 1.0, 1.46),
    ("Solar control", (0.34, 0.48, 0.53), 0.0, 0.08, 0.92, 1.48),
    ("Channel glass", (0.911, 0.966, 0.96), 0.0, 0.25, 1.0, 1.46),
    ("Car window", (0.22, 0.30, 0.31), 0.0, 0.06, 0.96, 1.46),
    ("Red lens", (0.8, 0.05, 0.02), 0.0, 0.1, 1.0, 1.5),
    ("Black tempered", (0.0, 0.0, 0.0), 0.0, 0.0, 1.0, 1.45),
]
solid_colors = [(0.9, 0.9, 0.9), (0.9, 0.5, 0.1), (0.9, 0.9, 0.9), (0.2, 0.6, 0.9), (0.9, 0.9, 0.9), (0.9, 0.5, 0.1)]
for i, (name, base, metallic, roughness, transmission, ior) in enumerate(panes):
    x = (i - (len(panes) - 1) / 2.0) * 1.7
    material, _ = principled(name, base, metallic, roughness, transmission, ior)
    box(name, (1.4, 0.02, 1.7), (x, 0.0, 1.0), material)
    # Something solid behind each pane.
    solid, _ = principled("Solid %d" % i, solid_colors[i], roughness=0.5)
    if i % 2 == 0:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=0.4, location=(x, 1.3, 0.75))
        bpy.ops.object.shade_smooth()
    else:
        bpy.ops.mesh.primitive_cube_add(size=0.7, location=(x, 1.3, 0.72), rotation=(0.0, 0.0, 0.5))
    behind = bpy.context.active_object
    behind.name = "Behind %d" % i
    behind.data.materials.append(solid)

# The camera of the reference view.
camera_data = bpy.data.cameras.new("Camera")
camera_data.sensor_fit = "VERTICAL"
camera_data.angle_y = math.radians(FOV_Y)
camera_data.clip_start = 0.05
camera_data.clip_end = 1000
camera = bpy.data.objects.new("Camera", camera_data)
camera.location = EYE
camera.rotation_euler = (TARGET - EYE).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(camera)
scene.camera = camera

# The stripes image travels inside the file.
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=out)
print("SAVED", out, [o.name for o in scene.objects])
