//
//  U4DKeyboardInput.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MVCTemplate__U4DKeyboardInput__
#define __MVCTemplate__U4DKeyboardInput__

#include <iostream>
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine {
class U4DTouches;
}

namespace U4DEngine {
class U4DKeyboardController:public U4DControllerInterface{

private:
    
public:
    
    //constructor
    U4DKeyboardController(){};
    
    //destructor
    ~U4DKeyboardController(){};
    
    //copy constructor
    U4DKeyboardController(const U4DKeyboardController& value){};
    U4DKeyboardController& operator=(const U4DKeyboardController& value){return *this;};
    
    void keyboardInput(int key);
    
   
};
}

#endif /* defined(__MVCTemplate__U4DKeyboardInput__) */
