import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

try:
    import numpy as np
except ImportError:  # the trainer needs numpy; the exporter's tests do not
    raise unittest.SkipTest("numpy is not installed")

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import train_mldeformer as t  # noqa: E402

np.seterr(divide="ignore", invalid="ignore", over="ignore")  # Accelerate BLAS false flags


def write_synthetic_dataset(base: Path, samples: int = 400, joints: int = 2, active: int = 40, seed: int = 3) -> None:
    """Deltas = smooth nonlinear function of the features plus a little noise."""
    rng = np.random.default_rng(seed)
    f = joints * 6
    features = rng.uniform(-1, 1, size=(samples, f)).astype(np.float32)
    mixing = rng.standard_normal((f, active * 6)).astype(np.float32) * 0.01
    deltas = np.tanh(features @ mixing * 3.0) * 0.02 + 0.002 * np.sin(features[:, :1]) + rng.normal(0, 1e-4, (samples, active * 6))
    header = {
        "version": 1,
        "sampleCount": samples,
        "featureCount": f,
        "activeCount": active,
        "channels": 6,
        "frameRate": 90.0,
        "jointPaths": [f"/root/j{i}" for i in range(joints)],
        "meshes": [
            {"name": "meshA", "vertexCount": 100, "activeStart": 0, "activeCount": active - 10},
            {"name": "meshB", "vertexCount": 50, "activeStart": active - 10, "activeCount": 10},
        ],
        "activeIndices": list(range(active - 10)) + list(range(10)),
        "features": base.name + ".features.f32",
        "deltas": base.name + ".deltas.f16",
    }
    Path(str(base) + ".json").write_text(json.dumps(header), encoding="utf-8")
    features.astype("<f4").tofile(str(base) + ".features.f32")
    deltas.astype("<f2").tofile(str(base) + ".deltas.f16")


class TrainMLDeformerTests(unittest.TestCase):
    def test_pca_reconstructs_low_rank_data(self) -> None:
        rng = np.random.default_rng(1)
        basis = rng.standard_normal((3, 60)).astype(np.float32)
        coefficients = rng.standard_normal((50, 3)).astype(np.float32)
        deltas = coefficients @ basis + 0.5
        mean, components, coeffs = t.pca(deltas, components=3)
        reconstructed = mean + coeffs @ components
        self.assertLess(float(np.abs(reconstructed - deltas).max()), 1e-3)
        self.assertEqual(components.shape, (3, 60))
        norms = np.linalg.norm(components, axis=1)
        np.testing.assert_allclose(norms, 1.0, atol=1e-4)

    def test_training_learns_synthetic_mapping_and_writes_payload(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory) / "synthetic"
            write_synthetic_dataset(base)
            dataset = t.load_dataset(base)
            result = t.train(dataset, components=8, hidden=32, epochs=120, lr=2e-3, batch=64, validation=0.1, seed=2, log=lambda _m: None)
            self.assertLess(result.validation_rms_mm, 4.0, f"validation error {result.validation_rms_mm} mm")
            signal = dataset.deltas.reshape(dataset.deltas.shape[0], -1, 6)[:, :, :3]
            signal_rms = float(np.sqrt(np.mean(np.sum(signal * signal, axis=2)))) * 1000
            self.assertLess(result.validation_rms_mm, signal_rms * 0.5, "the network must beat predicting nothing")

            output = Path(directory) / "synthetic.untoldml"
            t.write_payload(output, dataset, result)
            header = t.read_payload_header(output)
            self.assertEqual(header["version"], 1)
            self.assertEqual(header["featureCount"], 12)
            self.assertEqual(header["hiddenCount"], 32)
            self.assertEqual(header["componentCount"], 8)
            self.assertEqual(header["jointPaths"], ["/root/j0", "/root/j1"])
            self.assertEqual(header["meshes"][1]["activeStart"], 30)
            self.assertEqual(header["activeCount"], 40)
            with open(output, "rb") as handle:
                self.assertEqual(handle.read(8), b"UNTOLDML")

    def test_load_dataset_rejects_mismatched_arrays(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory) / "bad"
            write_synthetic_dataset(base, samples=20, active=8)
            with open(str(base) + ".features.f32", "ab") as handle:
                handle.write(struct.pack("<f", 1.0))
            with self.assertRaises(RuntimeError):
                t.load_dataset(base)


if __name__ == "__main__":
    unittest.main()
