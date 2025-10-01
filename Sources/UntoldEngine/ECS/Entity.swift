
//
//  Entity.swift
//  ECSinSwift
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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
