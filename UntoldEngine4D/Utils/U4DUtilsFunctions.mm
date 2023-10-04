//
//  U4DUtilsFunctions.cpp
//  Untold Engine iOS
//
//  Created by Harold Serrano on 9/17/23.
//

#include "U4DUtilsFunctions.h"

extern U4DEngine::callback updateCallbackFunction;

namespace U4DEngine {

void setUpdateCallback(callback uUpdateCallbackFunction){

    updateCallbackFunction=uUpdateCallbackFunction;
}

}


