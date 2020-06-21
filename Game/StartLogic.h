//
//  StartLogic.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/12/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef StartLogic_hpp
#define StartLogic_hpp

#include <stdio.h>
#include "U4DGameModel.h"

class StartLogic:public U4DEngine::U4DGameModel {

private:
    
public:
    
    StartLogic();
    
    ~StartLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveUserInputUpdate(void *uData);
};

#endif /* StartLogic_hpp */
