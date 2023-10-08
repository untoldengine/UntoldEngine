//
//  GameScene.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/3/23.
//  Copyright © 2023 Untold Engine Studios. All rights reserved.
//

#ifndef GameScene_hpp
#define GameScene_hpp

#include <stdio.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include "U4DRenderer.h"

struct GameScene{
  
    void init(MTKView *metalView);
    static void update();
    void handleInput();
    
    
    //data
    U4DRenderer *renderer;
    
};

#endif /* GameScene_hpp */
