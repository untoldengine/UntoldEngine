//
//  KeyboardController.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef KeyboardController_hpp
#define KeyboardController_hpp

#include <stdio.h>
#include "U4DKeyboardController.h"
#include "UserCommonProtocols.h"
#include "U4DMacKey.h"
#include "U4DMacArrowKey.h"
#include "U4DMacMouse.h"

class KeyboardController:public U4DEngine::U4DKeyboardController{
    
private:
    
    U4DEngine::U4DMacKey *macKeyA;
    U4DEngine::U4DMacKey *macKeyD;
    U4DEngine::U4DMacArrowKey *macArrowKeys;
    U4DEngine::U4DMacMouse *mouseLeftButton;
    
public:
    
    KeyboardController(){};
    
    
    ~KeyboardController(){};
    
    void init();
    
    void actionOnMacKeyA();
    
    void actionOnMacKeyD();
    
    void actionOnArrowKeys();
    
    void actionOnMouseLeftButton();
    
};
#endif /* KeyboardController_hpp */
