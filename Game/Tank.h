//
//  Tank.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Tank_hpp
#define Tank_hpp

#include <stdio.h>
#include <string>
#include "U4DGameObject.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "TankHead.h"

class Tank:public U4DEngine::U4DGameObject{
    
private:
    
    U4DEngine::U4DVector3n joyStickData;
    GameEntityState entityState;
    TankHead *tankHead;
    
public:
    
    Tank():joyStickData(0.0,0.0,0.0){};
    
    float x,y,z;
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(GameEntityState uState);
    
    void setState(GameEntityState uState);
    
    GameEntityState getState();
    
    TankHead* getTankHead();
    
    inline void setJoystickData(U4DEngine::U4DVector3n& uData){joyStickData=uData;}
    
};

#endif /* Tank_hpp */
