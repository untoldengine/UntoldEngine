//
//  SandboxWorld.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef DebugWorld_hpp
#define DebugWorld_hpp

#include <stdio.h>
#include "U4DWorld.h"
#include "U4DModel.h"
#include "U4DButton.h"
#include "U4DJoystick.h"
#include "U4DSlider.h"
#include "U4DCheckbox.h"
#include "U4DWindow.h"
#include "U4DText.h"
#include "U4DAnimation.h"
#include "U4DParticleSystem.h"

class SandboxWorld:public U4DEngine::U4DWorld {
    
private:
    

    
public:
    
    SandboxWorld();
    
    ~SandboxWorld();
    
    void init();
    
    void update(double dt);

    //Sets the configuration for the engine: Perspective view, shadows, light
    void setupConfiguration();
    
    void actionOnButtonA();
    
    void actionOnCheckbox();
    
    void actionOnCheckboxB();
    
    void actionOnCheckboxC();
    
    void actionOnCheckboxD();
    
    void actionOnSliderA();
    
};
#endif /* DebugWorld_hpp */
