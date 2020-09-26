//
//  LevelOneUILayer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef LevelOneUILayer_hpp
#define LevelOneUILayer_hpp

#include <stdio.h>
#include <string>
#include "U4DLayer.h"
#include "U4DJoystick.h"
#include "U4DButton.h"
#include "Player.h"

class LevelOneUILayer:public U4DEngine::U4DLayer{
  
private:
    
    U4DEngine::U4DButton *buttonA;
    U4DEngine::U4DButton *buttonB;
    U4DEngine::U4DJoystick *joystick;
    
    
public:
    
    LevelOneUILayer(std::string uLayerName);
    
    ~LevelOneUILayer();
    
    void init();
    
};

#endif /* LevelOneUILayer_hpp */
