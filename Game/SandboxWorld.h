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
#include "U4DGameObject.h"
#include "U4DButton.h"
#include "U4DJoystick.h"
#include "U4DSlider.h"
#include "U4DCheckbox.h"
#include "U4DText.h"

class SandboxWorld:public U4DEngine::U4DWorld {
    
private:
    
    U4DEngine::U4DGameObject *ground;
    U4DEngine::U4DButton *buttonA;
    U4DEngine::U4DJoystick *joystickA;
    U4DEngine::U4DSlider *sliderA;
    U4DEngine::U4DSlider *sliderB;
    U4DEngine::U4DText *xPosText;
    U4DEngine::U4DText *yPosText;
    U4DEngine::U4DText *zPosText;
    U4DEngine::U4DCheckbox *checkbox;
    U4DEngine::U4DCheckbox *checkboxB;
    U4DEngine::U4DGameObject *player;
    
    bool showCollisionVolume;
    bool showNarrowVolume;
    
public:
    
    SandboxWorld();
    
    ~SandboxWorld();
    
    void init();
    
    void update(double dt);

    //Sets the configuration for the engine: Perspective view, shadows, light
    void setupConfiguration();
    
    void actionOnButtonA();
    
    void actionOnSlider();
    
    void actionOnSliderB();
    
    void actionOnJoystick();
    
    void actionOnCheckbox();
    
    void actionOnCheckboxB();
    
};
#endif /* DebugWorld_hpp */
