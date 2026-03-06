//
//  EngineSignposts.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import os.signpost

public enum ProfileScope {
    case frame
    case update
    case renderPrep
    case encode
    case submit
}

final class EngineSignposts {
    private static let subsystem = "com.untoldengine.profiling"
    private static let log = OSLog(subsystem: subsystem, category: .pointsOfInterest)

    private static let frameSignpostID = OSSignpostID(log: log)
    private static let updateSignpostID = OSSignpostID(log: log)
    private static let renderPrepSignpostID = OSSignpostID(log: log)
    private static let encodeSignpostID = OSSignpostID(log: log)
    private static let submitSignpostID = OSSignpostID(log: log)

    private var activeScopes: [ProfileScope: OSSignpostID] = [:]

    func beginScope(_ scope: ProfileScope) {
        let signpostID = getSignpostID(for: scope)
        let name = getScopeName(scope)

        os_signpost(.begin, log: Self.log, name: name, signpostID: signpostID)
        activeScopes[scope] = signpostID
    }

    func endScope(_ scope: ProfileScope) {
        guard let signpostID = activeScopes[scope] else { return }
        let name = getScopeName(scope)

        os_signpost(.end, log: Self.log, name: name, signpostID: signpostID)
        activeScopes.removeValue(forKey: scope)
    }

    private func getSignpostID(for scope: ProfileScope) -> OSSignpostID {
        switch scope {
        case .frame: return Self.frameSignpostID
        case .update: return Self.updateSignpostID
        case .renderPrep: return Self.renderPrepSignpostID
        case .encode: return Self.encodeSignpostID
        case .submit: return Self.submitSignpostID
        }
    }

    private func getScopeName(_ scope: ProfileScope) -> StaticString {
        switch scope {
        case .frame: return "Frame"
        case .update: return "Update"
        case .renderPrep: return "RenderPrep"
        case .encode: return "Encode"
        case .submit: return "Submit"
        }
    }
}
