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

class StartMenu:public U4DEngine::U4DWorld {
    
private:

    U4DEngine::U4DButton *playButton;
    U4DEngine::U4DButton *quitButton;
    U4DEngine::U4DLayer *menuLayer;
    
public:
    
    StartMenu();
    
    ~StartMenu();
    
    void init();
    
    void update(double dt);

    //Sets the configuration for the engine: Perspective view, shadows, light
    void setupConfiguration();
    
    void play();
    
};

#endif /* StartMenu_hpp */
