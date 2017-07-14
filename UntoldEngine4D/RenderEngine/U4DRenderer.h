//
//  U4DRenderer.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/1/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#ifndef U4DRenderer_hpp
#define U4DRenderer_hpp

#import <MetalKit/MetalKit.h>

@interface U4DRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;

@end

#endif /* U4DRenderer_hpp */
