//
//  U4DBoneData.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoneData__
#define __UntoldEngine__U4DBoneData__

#include <iostream>
#include <vector>
#include <string>

#include "U4DMatrix4n.h"
#include "U4DDualQuaternion.h"
#include "CommonProtocols.h"
#include "U4DEntityNode.h"

namespace U4DEngine {

/**
 @brief The U4DBoneData class holds bone information for the 3D entity
 */
class U4DBoneData:public U4DEntityNode<U4DBoneData>{
    
private:
    
    
public:

    /**
     @brief Constructor for the class
     */
    U4DBoneData();
    
    /**
     @brief Destructor for the class
     */
    ~U4DBoneData();
    
    /**
     @brief Name of bone
     */
    std::string name;
    
    /**
     @brief Index of bone
     */
    int index;
    
    /**
     @brief Local space of the bone
     */
    U4DDualQuaternion localSpace;
    
    /**
     @brief Absolute space of the bone
     */
    U4DDualQuaternion absoluteSpace;
    
    /**
     @brief Final space of the bone. Not currently used. Use finalSpaceMatrix instead.
     */
    //U4DDualQuaternion finalSpace;
    
    /**
     @brief Final space matrix of the bone
     */
    U4DMatrix4n finalSpaceMatrix;

    /**
     @brief Inverse bind pose space of the bone
     */
    U4DDualQuaternion inverseBindPoseSpace;

    /**
     @brief Bind pose space of the bone
     */
    U4DDualQuaternion bindPoseSpace;
  
    /**
     @brief Absolute space of the bone in rest position
     */
    U4DDualQuaternion restAbsolutePoseSpace;
    
    /**
     @brief Pose space of the bone during animation
     */
    U4DDualQuaternion animationPoseSpace;
    
    /**
     @brief Container holding the vertex weights of the bone
     */
    std::vector<float> vertexWeightContainer;
    
    /**
     @brief Gets the pose animation space of the bone

     @return The pose space animation of the bone
     */
    U4DDualQuaternion getBoneAnimationPoseSpace();
    
    std::string getName();
};
    
}

#endif /* defined(__UntoldEngine__U4DBoneData__) */
