//
//  U4DBoneData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#include "U4DBoneData.h"

namespace U4DEngine {
    
    U4DBoneData::U4DBoneData(){

        index=0;    //set index number as zero
        
    }

    U4DBoneData::~U4DBoneData(){

    }
    
    U4DDualQuaternion U4DBoneData::getBoneAnimationPoseSpace(){
        
        return animationPoseSpace;
    }

    std::string U4DBoneData::getName(){
        return name;
    }

}
