//
//  U4DTouchesController.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DTouchesController.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
    //constructor
    U4DTouchesController::U4DTouchesController(){}

    //destructor
    U4DTouchesController::~U4DTouchesController(){}
        
    void U4DTouchesController::init(){
        
           userTouch=new U4DTouches(U4DEngine::ioTouch,this);
           
           registerInputEntity(userTouch);
        
    }
    

}
