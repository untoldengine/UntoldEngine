
//
//  Entity.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

func createEntityId(_ index: EntityIndex, _ version: EntityVersion) -> EntityID {
    // entity index is in upper 32 bits. version is lower 32 bits
    let shiftedIndex = EntityID(index) << 32
    let versionId = EntityID(version)

    return shiftedIndex | versionId
}

func getEntityIndex(_ index: EntityID) -> EntityIndex {
    // shift down 32 so we get rid of the version and return index
    EntityIndex(index >> 32)
}

func getEntityVersion(_ index: EntityID) -> EntityVersion {
    EntityVersion(UInt32(index & 0xFFFF_FFFF))
}
