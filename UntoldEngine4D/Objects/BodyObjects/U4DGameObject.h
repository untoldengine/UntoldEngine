//
//  U4DGameObject.h
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
    class U4DGameObject:public U4DDynamicModel{
        
    private:
        
           
    public:
        
        
        U4DGameObject();
        
        U4DGameObject(const char*);
        
        ~U4DGameObject();
        
        U4DGameObject(const U4DGameObject& value);

        U4DGameObject& operator=(const U4DGameObject& value);
        
        virtual void update(double dt){};
        
        bool loadModel(const char* uModelName, const char* uBlenderFile);
        
        bool loadAnimationToModel(U4DAnimation *uAnimation, const char* uAnimationName, const char* uBlenderFile);
        
    };

}

#endif /* defined(__MVCTemplate__U4DCharacter__) */
