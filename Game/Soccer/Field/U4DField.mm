//
//  U4DField.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/14/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DField.h"
#include "U4DGameConfigs.h"
#include "Constants.h"
#include "U4DTeamStateDefending.h"
#include "U4DBall.h"

namespace U4DEngine{

    U4DField::U4DField(){
        
    }

    U4DField::~U4DField(){
        
    }

    //init method. It loads all the rendering information among other things.
    bool U4DField::init(const char* uModelName){
        
        if (loadModel(uModelName)) {
            
            //setPipeline("fieldPipeline");
            
            loadRenderingInformation();
            
            return true;
        }
        
        return false;
        
    }

    void U4DField::update(double dt){
        
    }
    void U4DField::shadeField(U4DPlayer *uPlayer){
        
        U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
        
        float fieldHalfWidth=gameConfigs->getParameterForKey("fieldHalfWidth");
        float fieldHalfLength=gameConfigs->getParameterForKey("fieldHalfLength");
        
        //Update player position
        U4DVector3n pos=uPlayer->getAbsolutePosition();
        
        pos.x/=fieldHalfWidth;
        pos.z/=fieldHalfLength;
        
        U4DVector4n param0(pos.z,pos.x,0.0,0.0);
        updateShaderParameterContainer(0, param0);
        
        //comput the yaw of the hero soldier
        U4DVector3n v0=uPlayer->getEntityForwardVector();
        U4DMatrix3n m=uPlayer->getAbsoluteMatrixOrientation();
        
        U4DEngine::U4DVector3n xDir(1.0,0.0,0.0);
        U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);

        U4DEngine::U4DVector3n v1=m*v0;

        float yaw=v0.angle(v1);

        v1.normalize();

        if (xDir.dot(v1)>U4DEngine::zeroEpsilon) {

            yaw=360.0-yaw;
        }

        //send the yaw information to the navigation shader
        U4DVector4n paramAngle(yaw,0.0,0.0,0.0);
        updateShaderParameterContainer(1, paramAngle);
    
        if(uPlayer->getTeam()->getCurrentState()==U4DTeamStateDefending::sharedInstance()){
            
            U4DBall *ball=U4DBall::sharedInstance();
            
            U4DVector3n ballPosition=ball->getAbsolutePosition();
            
            ballPosition.x/=fieldHalfWidth;
            ballPosition.z/=fieldHalfLength;
            //send the ball information to the navigation shader
            U4DVector4n paramBallIndicator(ballPosition.z,ballPosition.x,1.0,0.0);
            updateShaderParameterContainer(2, paramBallIndicator);
            
        }else{
            
            //tell the shader not to draw the ball indicator
            U4DVector4n paramBallIndicator(0.0,0.0,0.0,0.0);
            updateShaderParameterContainer(2, paramBallIndicator);
        
        }
        
    }

    U4DAABB U4DField::getFieldAABB(){
        
        U4DVector3n fieldDimensions=getModelDimensions()*0.5;
        U4DMatrix3n m=getAbsoluteMatrixOrientation();
        fieldDimensions=m*fieldDimensions;
        U4DPoint3n center=getAbsolutePosition().toPoint();
        
        U4DAABB fieldAABB(std::abs(fieldDimensions.x),5.0,std::abs(fieldDimensions.z),center);
        
        return fieldAABB;
    }


}
