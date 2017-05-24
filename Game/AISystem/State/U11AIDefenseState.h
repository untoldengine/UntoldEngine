//
//  U11AIDefenseState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AIDefenseState_hpp
#define U11AIDefenseState_hpp

#include <stdio.h>
#include "U11AIStateInterface.h"

class U11AISystem;

class U11AIDefenseState:public U11AIStateInterface {
    
private:
    
    U11AIDefenseState();
    
    ~U11AIDefenseState();
    
public:
    
    static U11AIDefenseState* instance;
    
    static U11AIDefenseState* sharedInstance();
    
    void enter(U11AISystem *uAISystem);
    
    void execute(U11AISystem *uAISystem, double dt);
    
    void exit(U11AISystem *uAISystem);
    
    bool handleMessage(U11AISystem *uAISystem, Message &uMsg);
    
};
#endif /* U11AIDefenseState_hpp */
