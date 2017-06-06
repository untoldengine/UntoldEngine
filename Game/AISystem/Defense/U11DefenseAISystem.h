//
//  AIDefenseSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef AIDefenseSystem_hpp
#define AIDefenseSystem_hpp

#include <stdio.h>
#include "U11DefenseSystem.h"

class U11DefenseAISystem:public U11DefenseSystem {
    
private:
    

public:
    
    U11DefenseAISystem();
    
    ~U11DefenseAISystem();
    
    void assignDefendingPlayer();
    
};

#endif /* AIDefenseSystem_hpp */
