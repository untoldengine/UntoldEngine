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
        
        /**
         @brief returns the rest pose of the bone. Note, an armature must be present
         
         @param uBoneName name of the bone
         @param uBoneRestPoseMatrix bone rest pose matrix
         @return returns true if the rootbone rest pose exists. The uBoneRestPoseMatrix will contain the bone rest pose
         */
        bool getBoneRestPose(std::string uBoneName, U4DMatrix4n &uBoneRestPoseMatrix);

        /**
         @brief returns the animation pose of the bone. Note, an armature must be present and an animation must currently be playing.
         
         @param uBoneName name of the bone
         @param uAnimation current animation being played
         @param uBoneAnimationPoseMatrix bone animation pose matrix
         
         @return returns true along with the animation pose space of the bone. The uBoneAnimationPoseMatrix will contain the animation pose matrix.
         */
        bool getBoneAnimationPose(std::string uBoneName, U4DAnimation *uAnimation, U4DMatrix4n &uBoneAnimationPoseMatrix);
        
        bool loadModelRawData(const char* uModelName);
        
        bool loadAnimationRawToModel(U4DAnimation *uAnimation, const char* uAnimationName);
        
    };

}

#endif /* defined(__MVCTemplate__U4DCharacter__) */
