//
//  U11DefenseSystemInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11DefenseSystemInterface_hpp
#define U11DefenseSystemInterface_hpp

#include <stdio.h>

class U11Team;

class U11DefenseSystemInterface {
    
public:
    
    virtual ~U11DefenseSystemInterface(){};
    
    virtual void setTeam(U11Team *uTeam)=0;
    
    virtual void assignDefendingPlayer()=0;
    
    virtual void assignDefendingSupportPlayers()=0;
    
    virtual void computeDefendingSpace()=0;
    
    virtual void interceptPass()=0;
    
    virtual void startComputeDefendingSpaceTimer()=0;
    
    virtual void removeComputeDefendingSpaceTimer()=0;
    
};

#endif /* U11DefenseSystemInterface_hpp */
