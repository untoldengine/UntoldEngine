// Editor-only. The editor compiles this folder with UNTOLD_EDITOR defined; the game does not,
// so nothing below ends up in the game binary.
#if UNTOLD_EDITOR
    import UntoldComponentKit
    import UntoldEngine

    /// What this project adds to the editor's menu bar. The first argument of `@UntoldMenu` is
    /// one of the editor's fixed root menus; the second is the item, optionally under submenus.
    final class SampleTools: EditorExtension {
        enum ReportStyle: String, CaseIterable, UntoldMenuTitled {
            case brief
            case detailed

            var menuTitle: String {
                rawValue.capitalized
            }
        }

        @UntoldMenu(.debug, "Sample Project/Report Style") var reportStyle: ReportStyle = .brief

        @UntoldMenu(.debug, "Sample Project/Log Code Components", tooltip: "Writes every code component in the scene to the console.")
        var logComponents = UntoldMenuAction { (owner: EditorExtension) in
            (owner as? SampleTools)?.logSceneComponents()
        }

        override func onLoad() {
            Logger.log(message: "[SampleTools] loaded; report style: \(reportStyle.rawValue)")
        }

        override func menuDidChange(_: UntoldMenuDomain, _ path: String) {
            Logger.log(message: "[SampleTools] \(path) is now \(reportStyle.rawValue)")
        }

        private func logSceneComponents() {
            for entry in CodeComponentRegistry.shared.entries {
                let entities = CodeComponentSystem.shared.entities(withComponentNamed: entry.name)
                Logger.log(message: "[SampleTools] \(entry.name): \(entities.count) in scene")
                guard reportStyle == .detailed else { continue }
                for entity in entities {
                    let values = CodeComponentSystem.shared.slots(on: entity).first { $0.typeName == entry.name }?.payload ?? [:]
                    Logger.log(message: "[SampleTools]   \(getEntityName(entityId: entity)): \(values)")
                }
            }
        }
    }
#endif
