#!/usr/bin/env python3
"""
compare_psnr.py
Usage:
  compare_psnr.py <reference.png> <test.png> [--threshold 30] [--resize yes|no] [--mode gray|rgb]

Defaults:
  --threshold 30    -> fail if PSNR < 30 dB
  --resize yes      -> auto-resize TEST to REF size if dimensions differ
  --mode gray       -> convert both images to grayscale before PSNR

Exit codes:
  0  success (PSNR >= threshold)
  1  PSNR below threshold
  2  bad invocation / missing args
  3  file not found
  4  failed to read image
  5  shape mismatch and --resize=no
"""

import sys, os
import cv2
import numpy as np
from skimage.metrics import peak_signal_noise_ratio

def parse_args(argv):
    if len(argv) < 3:
        print("Usage: compare_psnr.py <reference.png> <test.png> [--threshold 30] [--resize yes|no] [--mode gray|rgb]", file=sys.stderr)
        sys.exit(2)
    ref_path = argv[1]
    test_path = argv[2]
    # defaults
    threshold = 30.0
    resize = "yes"  # auto-resize test to ref by default for CI convenience
    mode = "gray"   # PSNR on luminance is robust across BGR/RGB differences

    # simple flag parser
    i = 3
    while i < len(argv):
        if argv[i] == "--threshold" and i + 1 < len(argv):
            threshold = float(argv[i + 1]); i += 2
        elif argv[i] == "--resize" and i + 1 < len(argv):
            resize = argv[i + 1].lower(); i += 2
        elif argv[i] == "--mode" and i + 1 < len(argv):
            mode = argv[i + 1].lower(); i += 2
        else:
            print(f"Unknown/invalid arg: {argv[i]}", file=sys.stderr)
            sys.exit(2)
    return ref_path, test_path, threshold, resize, mode

def load(path: str):
    return cv2.imread(path, cv2.IMREAD_UNCHANGED)

def drop_alpha(img: np.ndarray):
    if img is not None and img.ndim == 3 and img.shape[2] == 4:
        return img[:, :, :3]
    return img

def to_gray(img: np.ndarray):
    if img is None:
        return None
    if img.ndim == 2:
        return img
    if img.ndim == 3 and img.shape[2] == 3:
        # OpenCV uses BGR; convert to grayscale
        return cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    # If something weird, coerce by averaging last axis
    return np.mean(img, axis=-1).astype(img.dtype)

def to_rgb(img: np.ndarray):
    if img is None:
        return None
    if img.ndim == 2:
        # gray -> 3ch
        return cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    if img.ndim == 3 and img.shape[2] == 3:
        # BGR -> RGB
        return cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    return img

def main():
    ref_path, test_path, threshold, resize, mode = parse_args(sys.argv)

    print(f"[compare_psnr] ref: {ref_path}")
    print(f"[compare_psnr] test: {test_path}")
    print(f"[compare_psnr] threshold={threshold}dB, resize={resize}, mode={mode}")

    # existence
    if not os.path.exists(ref_path):
        print(f"[compare_psnr] ERROR: reference not found: {ref_path}", file=sys.stderr)
        sys.exit(3)
    if not os.path.exists(test_path):
        print(f"[compare_psnr] ERROR: test not found: {test_path}", file=sys.stderr)
        sys.exit(3)

    ref = load(ref_path)
    test = load(test_path)

    if ref is None:
        print(f"[compare_psnr] ERROR: failed to read reference: {ref_path}", file=sys.stderr)
        sys.exit(4)
    if test is None:
        print(f"[compare_psnr] ERROR: failed to read test: {test_path}", file=sys.stderr)
        sys.exit(4)

    # Normalize channels
    ref = drop_alpha(ref)
    test = drop_alpha(test)

    # Size handling
    if ref.shape[:2] != test.shape[:2]:
        print(f"[compare_psnr] size mismatch: ref{ref.shape[:2]} vs test{test.shape[:2]}")
        if resize == "yes":
            # Resize TEST to REF size
            test = cv2.resize(test, (ref.shape[1], ref.shape[0]), interpolation=cv2.INTER_AREA)
            print(f"[compare_psnr] resized test -> {test.shape[:2]}")
        else:
            print(f"[compare_psnr] ERROR: dimensions differ and --resize=no", file=sys.stderr)
            sys.exit(5)

    # Color mode
    if mode == "gray":
        ref_use = to_gray(ref)
        test_use = to_gray(test)
    else:
        # Use 3-channel RGB for PSNR
        ref_use = to_rgb(ref)
        test_use = to_rgb(test)

    # Compute PSNR on uint8 directly (data_range=255)
    psnr = peak_signal_noise_ratio(ref_use, test_use, data_range=255)
    print(f"{psnr:.6f}")

    if psnr < threshold:
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()

