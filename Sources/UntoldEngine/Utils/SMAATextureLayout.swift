//
//  SMAATextureLayout.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

enum SMAATextureLayout {
    static let areaWidth = 160
    static let areaHeight = 560
    static let areaBytesPerPixel = 2
    static let areaBytesPerRow = areaWidth * areaBytesPerPixel
    static let areaByteCount = areaBytesPerRow * areaHeight

    static let searchWidth = 64
    static let searchHeight = 16
    static let searchBytesPerPixel = 1
    static let searchBytesPerRow = searchWidth * searchBytesPerPixel
    static let searchByteCount = searchBytesPerRow * searchHeight
}
