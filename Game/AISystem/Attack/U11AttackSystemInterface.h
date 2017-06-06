//
//  U11AttackSystemInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AttackSystemInterface_hpp
#define U11AttackSystemInterface_hpp

#include <stdio.h>

class U11Team;

class U11AttackSystemInterface {
    
public:
    
    virtual ~U11AttackSystemInterface(){};
    
    virtual void setTeam(U11Team *uTeam)=0;
    
    virtual void assignSupportPlayer()=0;
    
    virtual void computeSupportSpace()=0;
    
    virtual void startComputeSupportSpaceTimer()=0;
    
    virtual void removeComputeSupportSpaceTimer()=0;
    
};



#endif /* U11AttackSystemInterface_hpp */
