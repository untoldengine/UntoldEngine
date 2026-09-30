#!/usr/bin/env python3
"""Trains an Untold ML deformer from an MLDeformerBaker dataset.

The baker (engine `MLDeformerBaker` / `untoldengine bake-mldeformer`) records,
for many sampled poses, the pose features (6D rest-relative rotation of the
muscle joints) and the skin deltas the XPBD muscle simulation produced on the
active vertices (position + normal, 6 floats per vertex). This script:

  1. builds a PCA basis of the deltas (K components, via the Gram matrix so
     tens of thousands of vertices are cheap),
  2. trains a small MLP (features -> normalized PCA coefficients, two SiLU
     hidden layers, Adam) in plain numpy,
  3. writes the `.untoldml` payload the engine decodes on the GPU.

Usage:
  train_mldeformer.py --dataset out/spiderman --output spiderman.untoldml \
      [--components 48] [--hidden 128] [--epochs 600] [--lr 1e-3]

`--dataset` is the base path the baker wrote (`<base>.json`,
`<base>.features.f32`, `<base>.deltas.f16`).
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np

MAGIC = b"UNTOLDML"
VERSION = 1
CHANNELS = 6


@dataclass
class Dataset:
    features: np.ndarray  # (N, F) float32
    deltas: np.ndarray  # (N, A * 6) float32
    joint_paths: list[str]
    meshes: list[dict]
    active_indices: np.ndarray  # (A,) uint32
    frame_rate: float


def load_dataset(base: Path) -> Dataset:
    header = json.loads(Path(str(base) + ".json").read_text(encoding="utf-8"))
    if header.get("version") != 1:
        raise RuntimeError(f"Unsupported dataset version {header.get('version')}")
    n = int(header["sampleCount"])
    f = int(header["featureCount"])
    a = int(header["activeCount"])
    channels = int(header.get("channels", CHANNELS))
    if channels != CHANNELS:
        raise RuntimeError(f"Expected {CHANNELS} channels per vertex, dataset has {channels}")
    directory = base.parent
    features = np.fromfile(directory / header["features"], dtype="<f4")
    deltas = np.fromfile(directory / header["deltas"], dtype="<f2")
    if features.size != n * f or deltas.size != n * a * channels:
        raise RuntimeError("Dataset arrays do not match the header counts")
    return Dataset(
        features=features.reshape(n, f).astype(np.float32),
        deltas=deltas.reshape(n, a * channels).astype(np.float32),
        joint_paths=list(header["jointPaths"]),
        meshes=list(header["meshes"]),
        active_indices=np.asarray(header["activeIndices"], dtype=np.uint32),
        frame_rate=float(header.get("frameRate", 90.0)),
    )


# --- PCA ------------------------------------------------------------------


def pca(deltas: np.ndarray, components: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Returns (mean (D,), basis (K, D) unit rows, coefficients (N, K)).

    Uses the N x N Gram matrix: N (samples) is a few thousand while D
    (active vertices x 6) can be hundreds of thousands.
    """
    n = deltas.shape[0]
    mean = deltas.mean(axis=0)
    centered = (deltas - mean).astype(np.float64)
    k = max(1, min(components, n - 1, centered.shape[1]))
    gram = centered @ centered.T
    eigenvalues, eigenvectors = np.linalg.eigh(gram)
    order = np.argsort(eigenvalues)[::-1][:k]
    eigenvalues = np.clip(eigenvalues[order], 1e-12, None)
    u = eigenvectors[:, order]  # (N, K)
    singular = np.sqrt(eigenvalues)  # (K,)
    basis = (centered.T @ u) / singular  # (D, K), unit columns
    coefficients = centered @ basis  # (N, K)
    total = float(np.sum(centered * centered))
    explained = float(np.sum(eigenvalues)) / total if total > 0 else 1.0
    print(f"PCA: {k} components explain {explained * 100:.2f}% of the delta variance", flush=True)
    return mean.astype(np.float32), basis.T.astype(np.float32), coefficients.astype(np.float32)


# --- MLP ------------------------------------------------------------------


def silu(x: np.ndarray) -> np.ndarray:
    return x / (1.0 + np.exp(-x))


def silu_grad(x: np.ndarray) -> np.ndarray:
    s = 1.0 / (1.0 + np.exp(-x))
    return s * (1.0 + x * (1.0 - s))


@dataclass
class MLP:
    w1: np.ndarray
    b1: np.ndarray
    w2: np.ndarray
    b2: np.ndarray
    w3: np.ndarray
    b3: np.ndarray

    @staticmethod
    def create(inputs: int, hidden: int, outputs: int, rng: np.random.Generator) -> "MLP":
        def he(rows: int, cols: int) -> np.ndarray:
            return (rng.standard_normal((rows, cols)) * math.sqrt(2.0 / cols)).astype(np.float32)

        return MLP(
            he(hidden, inputs), np.zeros(hidden, np.float32),
            he(hidden, hidden), np.zeros(hidden, np.float32),
            (rng.standard_normal((outputs, hidden)) * math.sqrt(1.0 / hidden)).astype(np.float32), np.zeros(outputs, np.float32),
        )

    def forward(self, x: np.ndarray):
        z1 = x @ self.w1.T + self.b1
        h1 = silu(z1)
        z2 = h1 @ self.w2.T + self.b2
        h2 = silu(z2)
        out = h2 @ self.w3.T + self.b3
        return out, (x, z1, h1, z2, h2)

    def predict(self, x: np.ndarray) -> np.ndarray:
        return self.forward(x)[0]

    def params(self) -> list[np.ndarray]:
        return [self.w1, self.b1, self.w2, self.b2, self.w3, self.b3]

    def gradients(self, cache, d_out: np.ndarray) -> list[np.ndarray]:
        x, z1, h1, z2, h2 = cache
        g_w3 = d_out.T @ h2
        g_b3 = d_out.sum(axis=0)
        d_h2 = d_out @ self.w3
        d_z2 = d_h2 * silu_grad(z2)
        g_w2 = d_z2.T @ h1
        g_b2 = d_z2.sum(axis=0)
        d_h1 = d_z2 @ self.w2
        d_z1 = d_h1 * silu_grad(z1)
        g_w1 = d_z1.T @ x
        g_b1 = d_z1.sum(axis=0)
        return [g_w1, g_b1, g_w2, g_b2, g_w3, g_b3]


class Adam:
    def __init__(self, params: list[np.ndarray], lr: float, beta1: float = 0.9, beta2: float = 0.999, eps: float = 1e-8):
        self.lr, self.beta1, self.beta2, self.eps = lr, beta1, beta2, eps
        self.m = [np.zeros_like(p) for p in params]
        self.v = [np.zeros_like(p) for p in params]
        self.t = 0

    def step(self, params: list[np.ndarray], grads: list[np.ndarray], lr: float | None = None) -> None:
        self.t += 1
        lr = self.lr if lr is None else lr
        for i, (p, g) in enumerate(zip(params, grads)):
            self.m[i] = self.beta1 * self.m[i] + (1 - self.beta1) * g
            self.v[i] = self.beta2 * self.v[i] + (1 - self.beta2) * (g * g)
            m_hat = self.m[i] / (1 - self.beta1 ** self.t)
            v_hat = self.v[i] / (1 - self.beta2 ** self.t)
            p -= (lr * m_hat / (np.sqrt(v_hat) + self.eps)).astype(p.dtype)


@dataclass
class TrainResult:
    mlp: MLP
    input_mean: np.ndarray
    input_std: np.ndarray
    coefficient_scale: np.ndarray
    mean: np.ndarray
    basis: np.ndarray
    train_loss: float
    validation_rms_mm: float
    pca_floor_rms_mm: float


def train(
    dataset: Dataset,
    components: int = 48,
    hidden: int = 128,
    epochs: int = 600,
    lr: float = 1e-3,
    batch: int = 256,
    validation: float = 0.1,
    seed: int = 1,
    log=print,
) -> TrainResult:
    rng = np.random.default_rng(seed)
    n = dataset.features.shape[0]
    if n < 4:
        raise RuntimeError("Need at least 4 samples")

    order = rng.permutation(n)
    validation_count = int(round(n * validation)) if n >= 10 else 0
    val_idx, train_idx = order[:validation_count], order[validation_count:]

    input_mean = dataset.features[train_idx].mean(axis=0)
    input_std = dataset.features[train_idx].std(axis=0)
    input_std = np.where(input_std > 1e-6, input_std, 1.0).astype(np.float32)
    x_all = ((dataset.features - input_mean) / input_std).astype(np.float32)

    mean, basis, coefficients = pca(dataset.deltas[train_idx], components)
    # Coefficients of every sample (validation included) against the same basis.
    coefficients_all = (dataset.deltas - mean) @ basis.T
    coefficient_scale = coefficients_all[train_idx].std(axis=0)
    coefficient_scale = np.where(coefficient_scale > 1e-8, coefficient_scale, 1.0).astype(np.float32)
    y_all = (coefficients_all / coefficient_scale).astype(np.float32)

    mlp = MLP.create(x_all.shape[1], hidden, basis.shape[0], rng)
    optimizer = Adam(mlp.params(), lr)
    x_train, y_train = x_all[train_idx], y_all[train_idx]
    steps_per_epoch = max(1, math.ceil(len(train_idx) / batch))
    total_steps = epochs * steps_per_epoch
    step = 0
    train_loss = 0.0
    for epoch in range(epochs):
        perm = rng.permutation(len(train_idx))
        epoch_loss = 0.0
        for start in range(0, len(train_idx), batch):
            idx = perm[start : start + batch]
            out, cache = mlp.forward(x_train[idx])
            diff = out - y_train[idx]
            loss = float(np.mean(diff * diff))
            d_out = (2.0 / diff.size) * diff
            grads = mlp.gradients(cache, d_out.astype(np.float32))
            # Cosine learning-rate decay.
            current_lr = lr * 0.5 * (1.0 + math.cos(math.pi * step / max(1, total_steps)))
            optimizer.step(mlp.params(), grads, current_lr)
            epoch_loss += loss
            step += 1
        train_loss = epoch_loss / steps_per_epoch
        if epoch % max(1, epochs // 10) == 0 or epoch == epochs - 1:
            log(f"epoch {epoch + 1}/{epochs}: loss {train_loss:.5f}")

    def position_rms_mm(indices: np.ndarray, predicted_coefficients: np.ndarray) -> float:
        if len(indices) == 0:
            return 0.0
        reconstructed = mean + predicted_coefficients @ basis
        diff = (reconstructed - dataset.deltas[indices]).reshape(len(indices), -1, CHANNELS)[:, :, :3]
        return float(np.sqrt(np.mean(np.sum(diff * diff, axis=2)))) * 1000.0

    for name, array in (("weights", np.concatenate([p.ravel() for p in mlp.params()])), ("basis", basis), ("mean", mean)):
        if not np.all(np.isfinite(array)):
            raise RuntimeError(f"Training diverged: non-finite {name}")

    eval_idx = val_idx if validation_count > 0 else train_idx
    predicted = mlp.predict(x_all[eval_idx]) * coefficient_scale
    validation_rms = position_rms_mm(eval_idx, predicted)
    floor_rms = position_rms_mm(eval_idx, coefficients_all[eval_idx])
    signal = dataset.deltas[eval_idx].reshape(len(eval_idx), -1, CHANNELS)[:, :, :3]
    signal_rms = float(np.sqrt(np.mean(np.sum(signal * signal, axis=2)))) * 1000.0
    log(
        f"{'validation' if validation_count else 'training'} position error: "
        f"{validation_rms:.3f} mm RMS (PCA floor {floor_rms:.3f} mm, delta signal {signal_rms:.3f} mm RMS)"
    )
    return TrainResult(mlp, input_mean.astype(np.float32), input_std, coefficient_scale, mean, basis, train_loss, validation_rms, floor_rms)


# --- Payload ----------------------------------------------------------------


def write_payload(path: Path, dataset: Dataset, result: TrainResult) -> None:
    k, d = result.basis.shape
    a = d // CHANNELS
    hidden = result.mlp.b1.shape[0]
    features = dataset.features.shape[1]
    out = bytearray()
    out += MAGIC
    out += struct.pack("<8I", VERSION, features, hidden, k, len(dataset.joint_paths), len(dataset.meshes), a, 0)

    def put_string(value: str) -> None:
        encoded = value.encode("utf-8")
        out.extend(struct.pack("<I", len(encoded)))
        out.extend(encoded)

    for joint in dataset.joint_paths:
        put_string(joint)
    for mesh in dataset.meshes:
        put_string(str(mesh["name"]))
        out.extend(struct.pack("<3I", int(mesh["vertexCount"]), int(mesh["activeStart"]), int(mesh["activeCount"])))
    out.extend(np.ascontiguousarray(dataset.active_indices, dtype="<u4").tobytes())
    for array in (
        result.input_mean, result.input_std,
        result.mlp.w1, result.mlp.b1, result.mlp.w2, result.mlp.b2, result.mlp.w3, result.mlp.b3,
        result.coefficient_scale,
    ):
        out.extend(np.ascontiguousarray(array, dtype="<f4").tobytes())
    out.extend(np.ascontiguousarray(result.mean, dtype="<f2").tobytes())
    out.extend(np.ascontiguousarray(result.basis, dtype="<f2").tobytes())
    path.write_bytes(bytes(out))


def read_payload_header(path: Path) -> dict:
    """Parses the fixed header and tables of a `.untoldml` (for tests/tools)."""
    data = path.read_bytes()
    if data[:8] != MAGIC:
        raise RuntimeError("Not an .untoldml payload")
    version, features, hidden, k, joints, meshes, active, _flags = struct.unpack_from("<8I", data, 8)
    cursor = 8 + 32
    joint_paths = []
    for _ in range(joints):
        (length,) = struct.unpack_from("<I", data, cursor)
        cursor += 4
        joint_paths.append(data[cursor : cursor + length].decode("utf-8"))
        cursor += length
    mesh_list = []
    for _ in range(meshes):
        (length,) = struct.unpack_from("<I", data, cursor)
        cursor += 4
        name = data[cursor : cursor + length].decode("utf-8")
        cursor += length
        vertex_count, active_start, active_count = struct.unpack_from("<3I", data, cursor)
        cursor += 12
        mesh_list.append({"name": name, "vertexCount": vertex_count, "activeStart": active_start, "activeCount": active_count})
    expected = (
        active * 4
        + (2 * features + hidden * features + hidden + hidden * hidden + hidden + k * hidden + k + k) * 4
        + (active * CHANNELS + k * active * CHANNELS) * 2
    )
    if len(data) - cursor != expected:
        raise RuntimeError(f"Payload body is {len(data) - cursor} bytes, expected {expected}")
    return {
        "version": version, "featureCount": features, "hiddenCount": hidden, "componentCount": k,
        "jointPaths": joint_paths, "meshes": mesh_list, "activeCount": active, "bytes": len(data),
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Train an Untold ML deformer from a baked muscle dataset.")
    parser.add_argument("--dataset", required=True, help="Base path of the baked dataset (without .json)")
    parser.add_argument("--output", required=True, help="Output .untoldml payload")
    parser.add_argument("--components", type=int, default=48, help="PCA components (K)")
    parser.add_argument("--hidden", type=int, default=128, help="Hidden units per layer")
    parser.add_argument("--epochs", type=int, default=600)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--batch", type=int, default=256)
    parser.add_argument("--validation", type=float, default=0.1, help="Held-out fraction")
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args(argv[1:])

    # Accelerate's BLAS raises spurious floating-point flags on Apple silicon
    # for finite inputs; results are checked for finiteness explicitly.
    np.seterr(divide="ignore", invalid="ignore", over="ignore")
    dataset = load_dataset(Path(args.dataset))
    print(
        f"Dataset: {dataset.features.shape[0]} samples, {dataset.features.shape[1]} features "
        f"({len(dataset.joint_paths)} joints), {dataset.active_indices.size} active vertices over {len(dataset.meshes)} mesh(es)",
        flush=True,
    )
    result = train(
        dataset, components=args.components, hidden=args.hidden, epochs=args.epochs,
        lr=args.lr, batch=args.batch, validation=args.validation, seed=args.seed,
        log=lambda message: print(message, flush=True),
    )
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    write_payload(output, dataset, result)
    header = read_payload_header(output)
    print(f"Wrote {output} ({header['bytes'] / 1e6:.1f} MB): K={header['componentCount']}, hidden={header['hiddenCount']}, active={header['activeCount']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
