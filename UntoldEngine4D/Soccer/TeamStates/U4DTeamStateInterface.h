//
//  U4DTeamStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTeamStateInterface_hpp
#define U4DTeamStateInterface_hpp

#include <stdio.h>
#include "U4DTeam.h"
#include "CommonProtocols.h"

namespace U4DEngine{

class U4DTeamStateInterface {
        
private:
    
    
    
public:
    
    std::string name;
    
    virtual ~U4DTeamStateInterface(){};
    
    virtual void enter(U4DTeam *uTeam)=0;
    
    virtual void execute(U4DTeam *uTeam, double dt)=0;
    
    virtual void exit(U4DTeam *uTeam)=0;
    
    virtual bool handleMessage(U4DTeam *uTeam, Message &uMsg)=0;
    
    virtual bool isSafeToChangeState(U4DTeam *uTeam)=0;
    
};

}

#endif /* U4DTeamStateInterface_hpp */
