//
//  U4DWorld.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DWorld.h"
#include "U4DControllerInterface.h"
#include "U4DEntityManager.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
    //constructor
    U4DWorld::U4DWorld():shadowsEnabled(false){
        
        entityManager=new U4DEntityManager();
        entityManager->setRootEntity(this);
        
        openGlManager=new U4DOpenGLWorld(this);
        openGlManager->setShader("gouraudShader");
        
        enableShadows();
        
    }
    
    
    //copy constructor
    U4DWorld::U4DWorld(const U4DWorld& value){
    
    }
    
    U4DWorld& U4DWorld::operator=(const U4DWorld& value){
    
        return *this;
    
    }
    
    
    void U4DWorld::draw(){
        
        openGlManager->draw();
        
    }

    void U4DWorld::getShadows(){
        
        if (shadowsEnabled==true) {
            
            
            openGlManager->startShadowMapPass();
            
            //for each children get the shadow
            U4DEntity* child=next;
            
            while (child!=NULL) {
                
                if(child->getEntityType()==MODEL){
                    
                    child->drawDepthOnFrameBuffer();
                    
                }
                
                child=child->next;
            }
            
            openGlManager->endShadowMapPass();
            
            
        }
       
        
    }

    void U4DWorld::setGameController(U4DControllerInterface* uGameController){
        
        gameController=uGameController;
        
    }


    void U4DWorld::setEntityControlledByController(U4DEntity *uEntity){
       
        gameController->setEntityToControl(uEntity);

    }

    void U4DWorld::enableShadows(){
        
        shadowsEnabled=true;
        openGlManager->initShadowMapFramebuffer();
        
    }

    void U4DWorld::disableShadows(){
        
        shadowsEnabled=false;
        
    }

    void U4DWorld::startShadowMapPass(){
        
        openGlManager->startShadowMapPass();
    }

    void U4DWorld::endShadowMapPass(){
        
        openGlManager->endShadowMapPass();
    }


    void U4DWorld::initLoadingModels(){
        
        U4DEntity *child=this;
        
        //load rendering info for every child
        while (child!=NULL) {
            
            child->loadRenderingInformation();
            child=child->next;
        }
        
    }

}
