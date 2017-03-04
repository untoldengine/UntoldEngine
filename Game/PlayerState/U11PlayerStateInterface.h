//
//  U11PlayerStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerStateInterface_hpp
#define U11PlayerStateInterface_hpp

#include <stdio.h>
#include "U11Player.h"
#include "UserCommonProtocols.h"

class U11PlayerStateInterface {
    
    
public:
    
    virtual ~U11PlayerStateInterface(){};
    
    virtual void enter(U11Player *uPlayer)=0;
    
    virtual void execute(U11Player *uPlayer, double dt)=0;
    
    virtual void exit(U11Player *uPlayer)=0;
    
    virtual bool handleMessage(U11Player *uPlayer, Message &uMsg)=0;
    
    virtual bool isSafeToChangeState(U11Player *uPlayer)=0;
    
};

#endif /* U11PlayerStateInterface_hpp */
