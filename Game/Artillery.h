//
//  Artillery.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Artillery_hpp
#define Artillery_hpp

#include <stdio.h>
#include <string>
#include "U4DGameObject.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"


class Artillery:public U4DEngine::U4DGameObject{
    
private:
    
    GameEntityState entityState;
    
protected:
    
    U4DEngine::U4DVector3n joyStickData;
    
public:
    
    Artillery():joyStickData(0.0,0.0,0.0){};
    
    float x,y,z;
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(GameEntityState uState);
    
    void setState(GameEntityState uState);
    
    GameEntityState getState();
    
    inline void setJoystickData(U4DEngine::U4DVector3n& uData){joyStickData=uData;}

};
#endif /* Artillery_hpp */
