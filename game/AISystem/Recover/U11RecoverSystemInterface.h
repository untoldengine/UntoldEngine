//
//  U11RecoverSystemInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11RecoverSystemInterface_hpp
#define U11RecoverSystemInterface_hpp

#include <stdio.h>

class U11Team;

class U11RecoverSystemInterface {
    
public:
    
    virtual ~U11RecoverSystemInterface(){};
    
    virtual void setTeam(U11Team *uTeam)=0;
    
    virtual void computeClosestPlayerToBall()=0;
    
    virtual void startComputeClosestPlayerTimer()=0;
    
    virtual void removeComputeClosestPlayerTimer()=0;

};

#endif /* U11RecoverSystemInterface_hpp */
