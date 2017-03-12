//
//  U11AIStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AIStateManager_hpp
#define U11AIStateManager_hpp

#include <stdio.h>
#include "U11AIStateInterface.h"

class U11AIStrategyInterface;

class U11AIStateManager {
    
private:
    
    U11AIStateInterface *previousState;
    
    U11AIStateInterface *currentState;
    
    U11AIStateInterface *nextState;
    

public:
    
    U11AIStateManager();
    
    ~U11AIStateManager();
    
    void changeState(U11AIStateInterface *uState);
    
    void update(double dt);

};

#endif /* U11AIStateManager_hpp */
