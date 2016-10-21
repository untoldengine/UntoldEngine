//
//  GameController.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__GameController__
#define __UntoldEngine__GameController__

#include <iostream>
#include "U4DTouchesController.h"
#include "U4DVector3n.h"
#include "UserCommonProtocols.h"

class GameController:public U4DEngine::U4DTouchesController{
  
private:
    
    float z;
    U4DEngine::U4DJoyStick *joyStick;
    U4DEngine::U4DButton *myButton;
    U4DEngine::U4DButton *myButtonB;
    
    U4DEngine::U4DVector3n data;
    
public:
    
    GameController():z(0.0){
        
        
      
    };
    
    
    ~GameController(){};
    
    void init();

};

#endif /* defined(__UntoldEngine__GameController__) */
