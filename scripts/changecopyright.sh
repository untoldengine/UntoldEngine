YEAR=$(date +"%Y")

find . -name "*.swift" -type f -exec sed -i '' "1,/Created by/s#//.*Created by.*#//  Copyright (C) Untold Engine Studios\n//  Licensed under the GNU LGPL v3.0 or later.\n//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.#" {} +

