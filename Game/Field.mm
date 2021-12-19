//
//  Field.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/28/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "Field.h"

Field::Field(){
    
}

Field::~Field(){
    
    delete kineticAction;
}

//init method. It loads all the rendering information among other things.
bool Field::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        //setPipeline("fieldPipeline");
        
//        kineticAction=new U4DEngine::U4DDynamicAction(this);
//
//        kineticAction->enableCollisionBehavior();
        
        loadRenderingInformation();
        
        return true;
    }
    
    return false;
}

void Field::update(double dt){
    
}
