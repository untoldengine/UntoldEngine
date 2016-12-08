//
//  Weapon.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Weapon_hpp
#define Weapon_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "WeaponBehavior.h"
#include "UserCommonProtocols.h"

class Weapon:public U4DEngine::U4DGameObject {
    
private:
    
    GameEntityState entityState;
    
    WeaponBehavior *aimBehavior;
    
protected:
    
    U4DEngine::U4DVector3n joyStickData;
    
public:
    
    Weapon();
    
    ~Weapon();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void setWeaponBehavior(WeaponBehavior *uWeaponBehavior);
    
    void aim(U4DEngine::U4DVector3n &uTarget);
    
    void changeState(GameEntityState uState);
    
    void setState(GameEntityState uState);
    
    GameEntityState getState();
    
    inline void setJoystickData(U4DEngine::U4DVector3n& uData){joyStickData=uData;}
    
};
#endif /* Weapon_hpp */
