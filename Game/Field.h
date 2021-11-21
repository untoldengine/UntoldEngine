//
//  Field.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/28/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef Field_hpp
#define Field_hpp

#include <stdio.h>
#include "U4DModel.h"
#include "U4DDynamicAction.h"

class Field:public U4DEngine::U4DModel {
    
private:
    
    U4DEngine::U4DDynamicAction *kineticAction;
    
public:
    
    Field();
    
    ~Field();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
};
#endif /* Field_hpp */
