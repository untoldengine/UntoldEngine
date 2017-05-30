//
//  U11AIRecoverState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AIRecoverState_hpp
#define U11AIRecoverState_hpp

#include <stdio.h>
#include "U11AIStateInterface.h"

class U11AISystem;

class U11AIRecoverState:public U11AIStateInterface {
    
private:
    
    U11AIRecoverState();
    
    ~U11AIRecoverState();
    
public:
    
    static U11AIRecoverState* instance;
    
    static U11AIRecoverState* sharedInstance();
    
    void enter(U11AISystem *uAISystem);
    
    void execute(U11AISystem *uAISystem, double dt);
    
    void exit(U11AISystem *uAISystem);
    
    bool handleMessage(U11AISystem *uAISystem, Message &uMsg);
    
};
#endif /* U11AIRecoverState_hpp */
