//
//  MenuLogic.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef MenuLogic_hpp
#define MenuLogic_hpp

#include <stdio.h>
#include "U4DGameModel.h"
#include "MenuWorld.h"

class MenuLogic:public U4DEngine::U4DGameModel {

private:
    
    MenuWorld *pMenu;
    
    bool stickBounce;
    
public:
    
    MenuLogic();
    
    ~MenuLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveUserInputUpdate(void *uData);
};
#endif /* MenuLogic_hpp */
