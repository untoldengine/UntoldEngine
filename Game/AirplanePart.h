//
//  AirplaneParts.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef AirplaneParts_hpp
#define AirplaneParts_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "UserCommonProtocols.h"

class AirplanePart:public U4DEngine::U4DGameObject {
    
private:
    
     GameEntityState entityState;
    
public:
    AirplanePart(){};
    ~AirplanePart(){};
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(GameEntityState uState);
    
    void setState(GameEntityState uState);
    
    GameEntityState getState();
    
};
#endif /* AirplaneParts_hpp */
