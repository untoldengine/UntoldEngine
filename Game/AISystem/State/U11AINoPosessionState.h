//
//  U11AINoPosessionState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AINoPosessionState_hpp
#define U11AINoPosessionState_hpp

#include <stdio.h>
#include "U11AIStateInterface.h"

class U11AISystem;

class U11AINoPosessionState:public U11AIStateInterface {
    
private:
    
    U11AINoPosessionState();
    
    ~U11AINoPosessionState();
    
public:
    
    static U11AINoPosessionState* instance;
    
    static U11AINoPosessionState* sharedInstance();
    
    void enter(U11AISystem *uAISystem);
    
    void execute(U11AISystem *uAISystem, double dt);
    
    void exit(U11AISystem *uAISystem);
    
    bool handleMessage(U11AISystem *uAISystem, Message &uMsg);
    
};
#endif /* U11AINoPosessionState_hpp */
