//
//  U11TeamStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11TeamStateInterface_hpp
#define U11TeamStateInterface_hpp

#include <stdio.h>
#include "UserCommonProtocols.h"

class U11Team;

class U11TeamStateInterface {
    
public:
    
    virtual ~U11TeamStateInterface(){};
    
    virtual void enter(U11Team *uTeam)=0;
    
    virtual void execute(U11Team *uTeam, double dt)=0;
    
    virtual void exit(U11Team *uTeam)=0;
    
    virtual bool handleMessage(U11Team *uTeam, Message &uMsg)=0;
    
};
#endif /* U11TeamStateInterface_hpp */
