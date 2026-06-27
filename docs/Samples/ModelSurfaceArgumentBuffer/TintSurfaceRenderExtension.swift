import Foundation
import simd
import UntoldEngine

/// Opt-in component that marks an entity for the tint surface pass.
///
/// A model is drawn by this extension only after this component is attached to
/// the entity. Extension-specific settings also belong on this component so
/// they can be encoded separately for each entity.
public final class TintSurfaceComponent: Component {
    /// Source tint whose RGB output is premultiplied by the fragment shader.
    public var color = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)

    /// Components require a default initializer so the ECS can create them.
    public required init() {}
}

/// Complete model-surface Rendering Extension using one argument-buffer value.
///
/// The implementation has four responsibilities:
/// 1. Register the shader library that owns the custom fragment function.
/// 2. Declare the argument IDs shared by Swift and Metal.
/// 3. Create a model-surface pipeline using that shader and layout.
/// 4. Add a graph pass that selects entities and encodes per-entity arguments.
public final class TintSurfaceRenderExtension: RenderExtension, @unchecked Sendable {
    /// Stable owner ID used by the engine to register and remove this extension.
    public let id = "sample.tintSurface"

    // Registry IDs are global, so namespace every ID owned by the extension.
    private let shaderLibraryID: RenderShaderLibraryID = "sample.tintSurface.shaders"
    private let pipelineID: RenderPipelineType = "sample.tintSurface.pipeline"
    private let argumentLayoutID = "sample.tintSurface.arguments"
    private let passID = "sample.tintSurface.draw"
    private let shaderBundle: Bundle?
    private let shaderLibraryURL: URL?

    /// Creates an extension that loads a bundle's default Metal library.
    ///
    /// Use the default for an Xcode application target. A framework should pass
    /// its framework bundle explicitly.
    public init(shaderBundle: Bundle = .main) {
        self.shaderBundle = shaderBundle
        shaderLibraryURL = nil
    }

    /// Creates an extension that loads a precompiled Metal library.
    ///
    /// Use this initializer when a Swift package bundles a `.metallib` resource.
    public init(shaderLibraryURL: URL) {
        shaderBundle = nil
        self.shaderLibraryURL = shaderLibraryURL
    }

    /// Registers the library containing `tintSurfaceFragment`.
    ///
    /// This hook is optional for extensions that use only engine shaders. This
    /// sample implements it because its fragment function is extension-owned.
    public func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
        if let shaderLibraryURL {
            registry.registerLibrary(shaderLibraryID, url: shaderLibraryURL)
        } else if let shaderBundle {
            registry.registerDefaultLibrary(shaderLibraryID, bundle: shaderBundle)
        }
    }

    /// Declares the local argument IDs used by the extension fragment shader.
    ///
    /// `buffer0` here must match `arguments.buffer0` in `TintSurface.metal`.
    /// Other extensions may also use `buffer0` because argument IDs are local
    /// to each extension draw.
    public func registerArgumentBuffers(_ registry: RenderExtensionArgumentBufferRegistry) {
        registry.registerArgumentBuffer(
            RenderExtensionArgumentBufferDescriptor(
                id: argumentLayoutID,
                buffers: [
                    RenderExtensionArgumentBuffer(
                        id: RenderExtensionModelSurfaceArgument.buffer0
                    ),
                ]
            )
        )
    }

    /// Creates the pipeline that combines the engine model vertex shader with
    /// the extension's fragment shader.
    ///
    /// Validation checks that the fragment shader uses the engine-owned outer
    /// argument-buffer slot and that this layout was registered.
    public func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerModelSurfacePipeline(
            pipelineID,
            fragmentShader: "tintSurfaceFragment",
            fragmentShaderLibrary: .registered(shaderLibraryID),
            depthEnabled: true,
            blendMode: .alphaPremultiplied,
            name: "Tint Surface",
            validation: .warn(argumentLayoutID: argumentLayoutID)
        )
    }

    /// Adds the extension's required render work to the engine graph.
    ///
    /// `buildGraph` is the only required protocol function besides `id`. The
    /// engine calls it while constructing the graph; the pass closure executes
    /// later during each frame.
    public func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: .beforePostProcess) { [pipelineID, argumentLayoutID] context in
            // The helper supplies engine model bindings and draws only entities
            // carrying TintSurfaceComponent. bindArguments runs once per entity.
            context.drawModelSurfaceEntities(
                pipeline: pipelineID,
                matching: [TintSurfaceComponent.self],
                label: "Tint Surface",
                argumentLayoutID: argumentLayoutID,
                bindArguments: { arguments, entityID, _ in
                    guard let tint = getEntityComponent(
                        entityId: entityID,
                        componentType: TintSurfaceComponent.self
                    ) else {
                        return
                    }

                    var color = tint.color
                    // The Swift ID must match the Metal member read by the
                    // fragment shader. The engine owns the outer buffer slot.
                    arguments.setBytes(
                        &color,
                        id: RenderExtensionModelSurfaceArgument.buffer0
                    )
                }
            )
        }
    }
}
