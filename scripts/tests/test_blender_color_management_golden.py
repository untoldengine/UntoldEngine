from __future__ import annotations

import os
import shutil
import subprocess
import unittest
from pathlib import Path


@unittest.skipUnless(
    os.environ.get("UNTOLD_RUN_BLENDER_GOLDEN") == "1",
    "Set UNTOLD_RUN_BLENDER_GOLDEN=1 to run the Blender/OCIO numerical and image golden test",
)
class BlenderColorManagementGoldenTests(unittest.TestCase):
    def test_blender_transform_matches_runtime_lut_sampler(self) -> None:
        blender = os.environ.get("BLENDER_BIN") or shutil.which("blender")
        if blender is None:
            app_binary = Path("/Applications/Blender.app/Contents/MacOS/Blender")
            if app_binary.is_file():
                blender = str(app_binary)
        self.assertIsNotNone(blender, "Set BLENDER_BIN to the Blender executable")

        script = Path(__file__).with_name("blender_color_management_golden.py")
        result = subprocess.run(
            [
                str(blender),
                "--background",
                "--factory-startup",
                "--python",
                str(script),
            ],
            capture_output=True,
            text=True,
            timeout=180,
        )
        output = result.stdout + "\n" + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("UNTOLD_COLOR_GOLDEN ", output)


if __name__ == "__main__":
    unittest.main()
