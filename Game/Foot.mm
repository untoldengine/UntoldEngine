//
//  Foot.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/8/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "Foot.h"

Foot::Foot(){
    
}

Foot::~Foot(){
    delete kineticAction;
}

//init method. It loads all the rendering information among other things.
bool Foot::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        kineticAction=new U4DEngine::U4DDynamicAction(this);

        kineticAction->enableCollisionBehavior();
        
        loadRenderingInformation();
        
        return true;
    }
    
    return false;
}

void Foot::update(double dt){
    
}
