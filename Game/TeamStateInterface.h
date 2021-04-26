//
//  TeamStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef TeamStateInterface_hpp
#define TeamStateInterface_hpp

#include <stdio.h>
#include "Team.h"
#include "UserCommonProtocols.h"

class TeamStateInterface {
        
private:
    
    
    
public:
    
    std::string name;
    
    virtual ~TeamStateInterface(){};
    
    virtual void enter(Team *uTeam)=0;
    
    virtual void execute(Team *uTeam, double dt)=0;
    
    virtual void exit(Team *uTeam)=0;
    
    virtual bool handleMessage(Team *uTeam, Message &uMsg)=0;
    
    virtual bool isSafeToChangeState(Team *uTeam)=0;
    
};
#endif /* TeamStateInterface_hpp */
