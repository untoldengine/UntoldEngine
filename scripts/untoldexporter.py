#!/usr/bin/env python3

# Copyright (C) Untold Engine Studios
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from untoldexplorer import main


if __name__ == "__main__":
    raise SystemExit(main(__import__("sys").argv))
