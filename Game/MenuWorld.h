//
//  MenuWorld.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef MenuWorld_hpp
#define MenuWorld_hpp

#include <stdio.h>
#include "U4DLayer.h"
#include "U4DWorld.h"
#include "U4DShaderEntity.h"
#include "MainMenuLayer.h"
#include "PlayMenuLayer.h"

class MenuWorld:public U4DEngine::U4DWorld {
    
private:
    
    MainMenuLayer *mainMenuLayer;
    PlayMenuLayer *playMenuLayer;
    int state;
    
public:
    
    MenuWorld();

    ~MenuWorld();
    
    void init();
    
    void update(double dt);

    //Sets the configuration for the engine: Perspective view, shadows, light
    void setupConfiguration();
    
    void playOption();
    
    void selectOptionInMenu(int uValue);
    
    void removeActiveLayer();
    
    void selectKit(int uValue);
    
    void changeState(int uState);
    
    void setState(int uState);
    
    int getState();
    
};
#endif /* MenuWorld_hpp */
