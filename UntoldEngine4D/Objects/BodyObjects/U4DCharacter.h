//
//  U4DCharacter.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MVCTemplate__U4DCharacter__
#define __MVCTemplate__U4DCharacter__


#include <iostream>
#include <vector>
#include <string>

#include "CommonProtocols.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
/**
 *  Class in charge of all characters in the game engine.
 */
class U4DCharacter:public U4DDynamicModel{
    
private:
    
       
public:

    U4DCharacter(){};
    U4DCharacter(const char*){};
    
    ~U4DCharacter(){};
    
    U4DCharacter(const U4DCharacter& value){};

    U4DCharacter& operator=(const U4DCharacter& value){return *this;};
    
    virtual void update(double dt){};    
    
};

}

#endif /* defined(__MVCTemplate__U4DCharacter__) */
