//
//  StartMenu.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/12/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef StartMenu_hpp
#define StartMenu_hpp

#include <stdio.h>
#include "U4DWorld.h"
#include "U4DButton.h"
#include "U4DLayer.h"
#include "U4DText.h"

class StartMenu:public U4DEngine::U4DWorld {
    
private:

    U4DEngine::U4DButton *startButton;
    U4DEngine::U4DLayer *menuLayer;
    U4DEngine::U4DText *menuInstructions;
    
public:
    
    StartMenu();
    
    ~StartMenu();
    
    void init();
    
    void update(double dt);

    //Sets the configuration for the engine: Perspective view, shadows, light
    void setupConfiguration();
    
};

#endif /* StartMenu_hpp */
