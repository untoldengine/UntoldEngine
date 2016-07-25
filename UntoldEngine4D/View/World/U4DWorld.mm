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
    U4DWorld::U4DWorld():gravity(0.0,0.0,0.0),gridEnabled(false),shadowsEnabled(false){
        
        entityManager=new U4DEntityManager();
        entityManager->setRootEntity(this);
        
        openGlManager=new U4DOpenGLWorld(this);
        openGlManager->setShader("worldShader");
        
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
        openGlManager->setShader("simpleShader");
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

    void U4DWorld::buildGrid(){
        
        int gridsize=5;
        
        //grid box
        U4DVector3n backLeftCorner(-gridsize,0,-gridsize);
        U4DVector3n backRightCorner(gridsize,0,-gridsize);
        U4DVector3n frontLeftCorner(-gridsize,0,gridsize);
        U4DVector3n frontRightCorner(gridsize,0,gridsize);
        
        bodyCoordinates.addVerticesDataToContainer(backLeftCorner);
        bodyCoordinates.addVerticesDataToContainer(backRightCorner);
        
        bodyCoordinates.addVerticesDataToContainer(backLeftCorner);
        bodyCoordinates.addVerticesDataToContainer(frontLeftCorner);
        
        bodyCoordinates.addVerticesDataToContainer(backRightCorner);
        bodyCoordinates.addVerticesDataToContainer(frontRightCorner);
        
        bodyCoordinates.addVerticesDataToContainer(frontLeftCorner);
        bodyCoordinates.addVerticesDataToContainer(frontRightCorner);
        
        //grid lines
        for (int x=-gridsize; x<=gridsize; x++) {
            
            U4DVector3n startBackPoint(x,0,-gridsize);
            U4DVector3n endFrontPoint(x,0,gridsize);
        
            bodyCoordinates.addVerticesDataToContainer(startBackPoint);
            bodyCoordinates.addVerticesDataToContainer(endFrontPoint);
            
            U4DVector3n startLeftPoint(-gridsize,0,x);
            U4DVector3n endRightPoint(gridsize,0,x);
            
            bodyCoordinates.addVerticesDataToContainer(startLeftPoint);
            bodyCoordinates.addVerticesDataToContainer(endRightPoint);

        }
        
        //grid vertical line
        
        U4DVector3n startVerticalPoint(0,-2,0);
        U4DVector3n endVerticalPoint(0,2,0);

        bodyCoordinates.addVerticesDataToContainer(startVerticalPoint);
        bodyCoordinates.addVerticesDataToContainer(endVerticalPoint);


    }

    void U4DWorld::initLoadingModels(){
        
        //build the world
        
        if (gridEnabled==true) {
        
            buildGrid();
        
        }
        
        U4DEntity *child=this;
        
        //load rendering info for every child
        while (child!=NULL) {
            
            child->loadRenderingInformation();
            child=child->next;
        }
        
    }

    void U4DWorld::enableGrid(bool value){
        
        gridEnabled=value;
        
    }

    void U4DWorld::setGravity(U4DVector3n& uGravity){
     
        gravity=uGravity;
        
        entityManager->setGravity(gravity);
        
    }

    U4DVector3n U4DWorld::getGravity(){
        
       return gravity;

    }

}
