//
//  MainMenuLayer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/5/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef MainMenuLayer_hpp
#define MainMenuLayer_hpp

#include <stdio.h>
#include "U4DLayer.h"
#include "U4DShaderEntity.h"

class MainMenuLayer:public U4DEngine::U4DLayer {
    
private:
    
    U4DEngine::U4DShaderEntity *menuShader;
    int menuSelection;
    
public:
    
    MainMenuLayer(std::string uLayerName); 
    
    ~MainMenuLayer();
    
    void init();
    
    void selectOptionInMenu(int uValue);

};

#endif /* MainMenuLayer_hpp */
