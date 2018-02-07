//
//  Renderer.h
//  Untold4D Shared
//
//  Created by Harold Serrano on 2/6/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#import <MetalKit/MetalKit.h>

// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface Renderer : NSObject <MTKViewDelegate>

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;

@end

