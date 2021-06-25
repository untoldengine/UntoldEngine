//
//  SandboxEditLogic.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef SandboxEditLogic_hpp
#define SandboxEditLogic_hpp

#include <stdio.h>
#include "U4DGameLogic.h"
#include "U4DModel.h"

class SandboxEditLogic:public U4DEngine::U4DGameLogic{
    
private:
    
      
public:
    
    SandboxEditLogic();
    
    ~SandboxEditLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveUserInputUpdate(void *uData);
    
};
#endif /* SandboxEditLogic_hpp */
