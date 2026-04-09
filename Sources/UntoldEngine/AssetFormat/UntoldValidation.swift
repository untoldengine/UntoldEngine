//
//  UntoldValidation.swift
//  UntoldEngine
//
//  Validation rules and consistency checks for the cooked `.untold`
//  runtime asset container.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum UntoldValidationError: Error, Sendable, Equatable {
    case invalidMagic
    case unsupportedVersion(UInt32)
    case unsupportedCompression(UInt32)
    case missingRequiredChunk(UntoldChunkType)
    case misalignedChunkOffset(UInt64)
    case invalidMaterialIndex(UInt32)
    case invalidVertexStride(UInt32)
    case invalidIndexDataSize(expected: UInt64, actual: UInt64)
    case invalidVertexDataRange(offset: UInt64, size: UInt64, chunkSize: UInt64)
    case invalidIndexDataRange(offset: UInt64, size: UInt64, chunkSize: UInt64)
    case unsupportedEnumValue
    case contentHashMismatch
    case compressionOutputSizeMismatch(expected: UInt64, actual: UInt64)
}
