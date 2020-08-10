//
//  PlayMenuLayer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/5/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayMenuLayer_hpp
#define PlayMenuLayer_hpp

#include <stdio.h>
#include "U4DLayer.h"
#include "U4DGameObject.h"
#include "U4DAnimation.h"
#include "U4DShaderEntity.h"
#include "U4DButton.h"
#include "U4DJoystick.h"

class PlayMenuLayer:public U4DEngine::U4DLayer {

private:
    
    U4DEngine::U4DGameObject *player;
    U4DEngine::U4DAnimation *walkAnimation;
    U4DEngine::U4DShaderEntity *kitMenuShader;
    U4DEngine::U4DButton *aButton;
    U4DEngine::U4DJoyStick *joystick;
    int kitSelection;
    
public:
    
    PlayMenuLayer(std::string uLayerName);
    
    ~PlayMenuLayer();
    
    void init();
    
    void selectKit(int uValue);
    
};

#endif /* PlayMenuLayer_hpp */
