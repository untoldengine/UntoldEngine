//
//  Player.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/28/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef Player_hpp
#define Player_hpp

#include <stdio.h>
#include "U4DModel.h"
#include "U4DDynamicAction.h"
#include "U4DAnimation.h"

class Player:public U4DEngine::U4DModel {
    
private:
    
    U4DEngine::U4DDynamicAction *kineticAction;
    U4DEngine::U4DAnimation *runningAnimation;
    
public:
    
    Player();
    
    ~Player();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
};

#endif /* Player_hpp */
