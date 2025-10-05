#!/usr/bin/env bash
#
# -------------------------------------------------------------
#  update-copyright-headers.sh
# -------------------------------------------------------------
#  Description:
#    Updates all Swift source files in the repository with the
#    standard Untold Engine copyright and license header.
#
#    The script searches recursively for all `.swift` files and
#    replaces any line containing “Created by” with the standard
#    copyright and license notice. This helps ensure all source
#    files remain consistent with the Untold Engine’s licensing
#    policy (GNU LGPL v3.0 or later).
#
#  How it works:
#    - Uses `find` to locate all `.swift` files.
#    - Uses `sed` (in-place) to replace the "Created by" line
#      with the official copyright block.
#    - Inserts the current year dynamically.
#
#  Usage:
#    ./scripts/update-copyright-headers.sh
#
#  Notes:
#    - Run this script from the repository root.
#    - macOS-compatible (`sed -i ''` syntax). For Linux, remove
#      the empty string argument after `-i`.
#    - The current year is automatically inserted at runtime.
#    - Safe to re-run; it only affects lines containing
#      “Created by”.
#
# -------------------------------------------------------------

YEAR=$(date +"%Y")

find . -name "*.swift" -type f -exec sed -i '' "1,/Created by/s#//.*Created by.*#//  Copyright (C) Untold Engine Studios\n//  Licensed under the GNU LGPL v3.0 or later.\n//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.#" {} +

