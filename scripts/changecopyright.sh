#!/usr/bin/env bash
#
# -------------------------------------------------------------
#  changecopyright.sh
# -------------------------------------------------------------
#  Description:
#    Updates source file headers from previous legacy licensing
#    wording to the Mozilla Public License v2.0 wording.
#
#    The script preserves per-file header lines (such as filename)
#    and replaces only the old license block. For files without any
#    license header, it prepends a new MPL v2.0 header.
#
#  How it works:
#    - Uses `find` to locate source files with common C-style
#      comment headers (`.swift`, `.metal`, `.h`, `.m`, `.mm`,
#      `.c`, `.cc`, `.cpp`, `.hpp`).
#    - Uses `perl` (in-place, multiline) to replace the old
#      license block with the MPL v2.0 notice.
#    - If neither legacy nor MPL text exists in a file, prepends
#      a new MPL header using the current filename.
#
#  Usage:
#    ./scripts/changecopyright.sh
#
#  Notes:
#    - Run this script from the repository root.
#    - Requires `perl` (available by default on macOS).
#    - Safe to re-run; files with an existing MPL header are not
#      modified again.
#
# -------------------------------------------------------------

find . \
  \( -type d \( -name ".git" -o -name ".build" -o -name ".swiftpm" -o -name "checkouts" -o -name "DerivedData" \) -prune \) -o \
  -type f \( \
    -name "*.swift" -o \
    -name "*.metal" -o \
    -name "*.h" -o \
    -name "*.m" -o \
    -name "*.mm" -o \
    -name "*.c" -o \
    -name "*.cc" -o \
    -name "*.cpp" -o \
    -name "*.hpp" \
\) -exec perl -0777 -i -pe '
my $has_mpl = /^[ \t]*\/\/[ \t]*This Source Code Form is subject to the terms of the Mozilla Public/m;

my $replaced = s#^[ \t]*//[ \t]*Copyright \(C\) Untold Engine Studios[ \t]*\R^[ \t]*//[ \t]*Licensed under [^\r\n]*\.[ \t]*\R(?:^[ \t]*//[ \t]*See the LICENSE file or <https://[^>]+/> for details\.[ \t]*\R)?(?:^[ \t]*//[ \t]*Copyright [^\r\n]*All rights reserved\.[ \t]*\R)?(?:^[ \t]*//[ \t]*UntoldEngine[ \t]*\R)?(?:^[ \t]*//[ \t]*\R)?#// Copyright (C) Untold Engine Studios\n//\n// This Source Code Form is subject to the terms of the Mozilla Public\n// License, v. 2.0. If a copy of the MPL was not distributed with this\n// file, You can obtain one at https://mozilla.org/MPL/2.0/.\n#mg;

if (!$replaced && !$has_mpl) {
    my ($filename) = $ARGV =~ m{([^/]+)$};
    my $header = "//\n//  $filename\n//  UntoldEngine\n//\n// Copyright (C) Untold Engine Studios\n//\n// This Source Code Form is subject to the terms of the Mozilla Public\n// License, v. 2.0. If a copy of the MPL was not distributed with this\n// file, You can obtain one at https://mozilla.org/MPL/2.0/.\n\n";
    $_ = $header . $_;
}
' {} +
