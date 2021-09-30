//
//  U4DScriptBehavior.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/16/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptBehavior.h"
#include "U4DLogger.h"
#include "U4DScriptBindBehavior.h"
#include "CommonProtocols.h"

namespace U4DEngine{

    U4DScriptBehavior::U4DScriptBehavior(){
        
        setEntityType(U4DEngine::SCRIPT);
        
    }

    U4DScriptBehavior::~U4DScriptBehavior(){
        
        U4DEntity *parent=getParent();
        
        parent->removeChild(this);
        
    }

    void U4DScriptBehavior::init(){
        
    }

    void U4DScriptBehavior::update(double dt){
        
        U4DScriptBindBehavior *scriptBindBehavior=U4DScriptBindBehavior::sharedInstance();
        
        scriptBindBehavior->update(getScriptID(),dt);
        
    }

    void U4DScriptBehavior::destroy(){
        
    }


}
