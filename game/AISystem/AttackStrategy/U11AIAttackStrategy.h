//
//  U11AttackStrategy.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AIAttackStrategy_hpp
#define U11AIAttackStrategy_hpp

#include <stdio.h>
#include "U11AIAttackStrategyInterface.h"


class U11Team;

class U11AIAttackStrategy:public U11AIAttackStrategyInterface{
    
private:
    
    U11Team *team;
    
public:
    
    U11AIAttackStrategy();
    
    ~U11AIAttackStrategy();
    
    void setTeam(U11Team *uTeam);
    
    void analyzePlay();
    
    bool shouldPassForward();
    
    void dribble();
    
    void passForward();
    
};

#endif /* U11AIAttackStrategy_hpp */
