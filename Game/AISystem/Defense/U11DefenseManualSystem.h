//
//  U11DefenseManualSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11DefenseManualSystem_hpp
#define U11DefenseManualSystem_hpp

#include <stdio.h>
#include "U11DefenseSystem.h"

class U11DefenseManualSystem:public U11DefenseSystem {
    
public:
    
    U11DefenseManualSystem();
    
    ~U11DefenseManualSystem();
    
    void interceptPass();
    
    void assignDefendingPlayer();
    
};

#endif /* U11DefenseManualSystem_hpp */
