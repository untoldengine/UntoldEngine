//
//  U11AIAttackState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AIAttackState_hpp
#define U11AIAttackState_hpp

#include <stdio.h>
#include "U11AIStateInterface.h"

class U11AISystem;

class U11AIAttackState:public U11AIStateInterface {
    
private:
    
    U11AIAttackState();
    
    ~U11AIAttackState();
    
public:
    
    static U11AIAttackState* instance;
    
    static U11AIAttackState* sharedInstance();
    
    void enter(U11AISystem *uAISystem);
    
    void execute(U11AISystem *uAISystem, double dt);
    
    void exit(U11AISystem *uAISystem);
    
    bool handleMessage(U11AISystem *uAISystem, Message &uMsg);
    
};
#endif /* U11AIAttackState_hpp */
