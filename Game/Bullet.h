//
//  Bullet.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Bullet_hpp
#define Bullet_hpp

#include <stdio.h>
#include <string>
#include "U4DGameObject.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"

class Bullet:public U4DEngine::U4DGameObject {
    
private:
    GameEntityState entityState;
    
public:
    Bullet(){};
    ~Bullet(){};
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(GameEntityState uState);
    
    void setState(GameEntityState uState);
    
    GameEntityState getState();
    
};

#endif /* Bullet_hpp */
