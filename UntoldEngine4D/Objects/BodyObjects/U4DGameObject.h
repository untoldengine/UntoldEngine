//
//  U4DGameObject.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
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
     @ingroup gameobjects
     @brief The U4DGameObject class represents all characters in a game
     */
    class U4DGameObject:public U4DDynamicModel{
        
    private:
        
    public:
        
        /**
         @brief Constructor class
         */
        U4DGameObject();
        
        /**
         @brief Destructor class
         */
        ~U4DGameObject();
        
        /**
         @brief Copy constructor
         */
        U4DGameObject(const U4DGameObject& value);

        /**
         @brief Copy constructor
         */
        U4DGameObject& operator=(const U4DGameObject& value);

        /**
         @brief Method which updates the state of the game character
         
         @param dt Time-step value
         */
        virtual void update(double dt){};
        
        
        
    };

}

#endif /* defined(__MVCTemplate__U4DCharacter__) */
