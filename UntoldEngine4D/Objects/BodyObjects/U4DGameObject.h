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
        
        /**
         @brief Method which loads Digital Asset data into the game character
         
         @param uModelName   Name of the model in the Digital Asset File
         @param uBlenderFile Name of Digital Asset File
         
         @return Returns true if the digital asset data was successfully loaded
         */
        bool loadModel(const char* uModelName, const char* uBlenderFile);
        
        /**
         @brief Method which loads Animation data into the game character
         
         @param uAnimation     Pointer to the animation
         @param uAnimationName Name of the animation
         @param uBlenderFile   Name of Digital Asset File
         
         @return Returns true if the animation was successfully loaded
         */
        bool loadAnimationToModel(U4DAnimation *uAnimation, const char* uAnimationName, const char* uBlenderFile);
        
    };

}

#endif /* defined(__MVCTemplate__U4DCharacter__) */
