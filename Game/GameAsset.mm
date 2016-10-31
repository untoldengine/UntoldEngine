//
//  GameAsset.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/30/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "GameAsset.h"


void GameAsset::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        
    }
    
    
}

void GameAsset::update(double dt){
    
    //rotateBy(0.0,1.0,0.0);
}
