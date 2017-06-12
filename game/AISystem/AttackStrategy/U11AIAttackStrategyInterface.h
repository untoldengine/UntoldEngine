//
//  U11AIStrategyInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AIAttackStrategyInterface_hpp
#define U11AIAttackStrategyInterface_hpp

#include <stdio.h>

class U11Team;

class U11AIAttackStrategyInterface {
    
public:
    
    virtual ~U11AIAttackStrategyInterface(){};
    
    virtual void setTeam(U11Team *uTeam)=0;
    
    virtual void analyzePlay()=0;
    
};

#endif /* U11AIAttackStrategyInterface_hpp */
