import UntoldEngine
import simd
import Foundation

// Fixed verification harness. Do not edit.

buildScene()

var failures: [String] = []

if let body = findEntity(name: "body"), let turret = findEntity(name: "turret") {
    if getEntityParent(entityId: turret) != body {
        failures.append("Expected 'turret' to have 'body' as its parent")
    }
    if !getEntityChildren(parentId: body).contains(turret) {
        failures.append("Expected 'body' to list 'turret' among its children")
    }
} else {
    if findEntity(name: "body") == nil { failures.append("No entity named 'body' was found") }
    if findEntity(name: "turret") == nil { failures.append("No entity named 'turret' was found") }
}

if failures.isEmpty {
    print("ALL CHECKS PASSED")
    exit(0)
} else {
    print("CHECKS FAILED:")
    for f in failures { print("- \(f)") }
    exit(1)
}
