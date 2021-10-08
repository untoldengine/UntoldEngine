//
//  Player.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/28/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "Player.h"
#include "Foot.h"

Player::Player(){
    
}

Player::~Player(){
    delete kineticAction;
    delete runningAnimation;
    
}

//init method. It loads all the rendering information among other things.
bool Player::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        setPipeline("testPipeline");
        
        kineticAction=new U4DEngine::U4DDynamicAction(this);

        kineticAction->enableKineticsBehavior();

        kineticAction->enableCollisionBehavior();

        runningAnimation = new U4DEngine::U4DAnimation(this);
        
        if(loadAnimationToModel(runningAnimation, "running")){
            
        }
        
        //attach foot
        foot=new Foot();
        if(foot->init("rightfoot")){
            
            addChild(foot);
            
        }
        
        loadRenderingInformation();
        
        return true;
    }
    
    return false;
}

void Player::update(double dt){
    
}
