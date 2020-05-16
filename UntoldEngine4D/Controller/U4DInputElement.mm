//
//  U4DInputElement.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/8/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DInputElement.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {

    U4DInputElement::U4DInputElement(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface):inputElementType(uInputElementType),controllerInterface(uControllerInterface){
        
    }
        
    U4DInputElement::~U4DInputElement(){
        
    }

    INPUTELEMENTTYPE U4DInputElement::getInputElementType(){
        
        return inputElementType;
        
    }

    void U4DInputElement::setControllerInterface(U4DControllerInterface* uControllerInterface){
        
        controllerInterface=uControllerInterface;
        
    }

}
