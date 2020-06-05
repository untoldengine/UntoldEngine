//
//  MobileLayer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef MobileLayer_hpp
#define MobileLayer_hpp

#include <stdio.h>
#include <string>
#include "U4DLayer.h"
#include "U4DJoyStick.h"
#include "U4DButton.h"
#include "Player.h"

class MobileLayer:public U4DEngine::U4DLayer{
  
private:
    
    U4DEngine::U4DButton *buttonA;
    U4DEngine::U4DButton *buttonB;
    U4DEngine::U4DJoyStick *joystick;
    Player* pPlayer;
    
public:
    
    MobileLayer(std::string uLayerName);
    
    ~MobileLayer();
    
    void init();
    
    void actionOnButtonA();
    
    void actionOnButtonB();
    
    void actionOnJoystick();
    
    void setPlayer(Player *uPlayer);
    
};

#endif /* MobileLayer_hpp */
