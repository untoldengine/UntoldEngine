
//
//  Entity.swift
//  ECSinSwift
//
//  Created by Harold Serrano on 1/14/24.
//

import Foundation

public func createEntityId(_ index: EntityIndex, _ version: EntityVersion) -> EntityID {

  //entity index is in upper 32 bits. version is lower 32 bits
  let shiftedIndex = EntityID(index) << 32
  let versionId = EntityID(version)

  return shiftedIndex | versionId
}

public func getEntityIndex(_ index: EntityID) -> EntityIndex {
  //shift down 32 so we get rid of the version and return index
  return EntityIndex(index >> 32)
}

public func getEntityVersion(_ index: EntityID) -> EntityVersion {
  return EntityVersion(UInt32(index & 0xFFFF_FFFF))
}
