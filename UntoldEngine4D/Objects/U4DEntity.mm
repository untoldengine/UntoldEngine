//
//  U4DEntity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DEntity.h"
#include "U4DQuaternion.h"
#include "U4DMatrix4n.h"
#include "U4DMatrix3n.h"
#include "U4DTransformation.h"
#include "U4DLogger.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
    U4DEntity::U4DEntity():localOrientation(0,0,0),localPosition(0,0,0),entityForwardVector(0,0,-1),zDepth(100),scriptID(0){
        
        
        transformation=new U4DTransformation(this);
        
        //get id
        U4DDirector *director=U4DDirector::sharedInstance();
        
        entityId=director->getNewEntityId();
        
    }


    U4DEntity::~U4DEntity(){

        delete transformation;
    }


    U4DEntity::U4DEntity(const U4DEntity& value){
        
        localOrientation=value.localOrientation;
        localPosition=value.localPosition;
        localSpace=value.localSpace;
        transformation=value.transformation;
    }


    U4DEntity& U4DEntity::operator=(const U4DEntity& value){
        
        localOrientation=value.localOrientation;
        localPosition=value.localPosition;
        localSpace=value.localSpace;
        transformation=value.transformation;
        return *this;
    }

    void U4DEntity::setName(std::string uName){
        name=uName;
    }

    std::string U4DEntity::getName(){
        return name;
    }

    void U4DEntity::setEntityType(ENTITYTYPE uType){
        entityType=uType;
    }

    ENTITYTYPE U4DEntity::getEntityType(){
        return entityType;
    }

    int U4DEntity::getScriptID(){
        return scriptID;
    }

    int U4DEntity::getEntityId(){
        return entityId;
    }

    void U4DEntity::setScriptID(int uScriptID){
        scriptID=uScriptID;
    }

    void U4DEntity::setLocalSpace(U4DDualQuaternion &uLocalSpace){
        
        localSpace=uLocalSpace;
        
    }


    void U4DEntity::setLocalSpace(U4DMatrix4n &uMatrix){
        
        U4DDualQuaternion dualQuaternion;
        dualQuaternion.transformMatrix4nToDualQuaternion(uMatrix);
        
        //assign to body
        setLocalSpace(dualQuaternion);
    }


    U4DQuaternion U4DEntity::getLocalSpaceOrientation(){
        
        return localSpace.getRealQuaternionPart();
    }

    U4DQuaternion U4DEntity::getLocalSpacePosition(){
        
        return localSpace.getPureQuaternionPart();
    }

    U4DVector3n U4DEntity::getLocalOrientation(){
        
        localOrientation=getLocalSpaceOrientation().transformQuaternionToEulerAngles();
        
        return localOrientation;
    }

    U4DDualQuaternion U4DEntity::getLocalSpace(){
        
        return localSpace;
    }

    U4DDualQuaternion U4DEntity::getAbsoluteSpace(){
        
        U4DDualQuaternion space;
        
        U4DEntity *child=this;
        
        while (child!=nullptr) {
            
            space=space*child->getLocalSpace();
            
            child=child->getParent();
            
        }
        
        return space;
    }

    U4DQuaternion U4DEntity::getAbsoluteSpaceOrientation(){
        
        U4DDualQuaternion space=getAbsoluteSpace();
        
        return space.getRealQuaternionPart();
    }

    U4DQuaternion U4DEntity::getAbsoluteSpacePosition(){

        U4DDualQuaternion space=getAbsoluteSpace();
        
        return space.getPureQuaternionPart();
    }


    U4DVector3n U4DEntity::getLocalPosition(){
        
        U4DQuaternion pos=getLocalSpacePosition();
        
        localPosition.x=pos.v.x;
        localPosition.y=pos.v.y;
        localPosition.z=pos.v.z;
        
        return localPosition;
        
    }

    U4DVector3n U4DEntity::getEntityForwardVector(){
        
        return entityForwardVector;
        
    }
    
    void U4DEntity::setEntityForwardVector(U4DVector3n &uForwardVector){
        
        uForwardVector.normalize();
        entityForwardVector=uForwardVector;
    }

    void U4DEntity::setLocalSpaceOrientation(U4DQuaternion &uOrientation){
     
        localSpace.setRealQuaternionPart(uOrientation);
        
    }

    void U4DEntity::setLocalSpacePosition(U4DQuaternion &uPosition){
        
        localSpace.setPureQuaternionPart(uPosition);
        
    }


    U4DVector3n U4DEntity::getAbsoluteOrientation(){
        
        U4DQuaternion orientation=getAbsoluteSpaceOrientation();
        
        return orientation.transformQuaternionToEulerAngles();
        
    }

    U4DVector3n U4DEntity::getAbsolutePosition(){
        
        U4DQuaternion position=getAbsoluteSpacePosition();
        
        U4DVector3n pos(position.v.x,position.v.y,position.v.z);
        
        return pos;
        
    }

    U4DMatrix3n U4DEntity::getAbsoluteMatrixOrientation(){
        
        U4DQuaternion entityOrientation=getAbsoluteSpaceOrientation();
        
        U4DMatrix3n m=entityOrientation.transformQuaternionToMatrix3n();
        
        return m;
        
    }

    U4DMatrix3n U4DEntity::getLocalMatrixOrientation(){
        
        U4DQuaternion entityOrientation=getLocalSpaceOrientation();
        
        U4DMatrix3n m=entityOrientation.transformQuaternionToMatrix3n();
        
        return m;
    }

    //Transformation helper functions

    void U4DEntity::translateTo(U4DVector3n& translation){
        
        transformation->translateTo(translation);
    }

    void U4DEntity::translateTo(float x,float y, float z){
        transformation->translateTo(x,y,z);
    }
    
    void U4DEntity::translateTo(U4DVector2n &translation){
        transformation->translateTo(translation);
    }
    
    void U4DEntity::translateBy(float x,float y, float z){
        transformation->translateBy(x, y, z);
    }
    
    void U4DEntity::translateBy(U4DVector3n& translation){
        transformation->translateBy(translation);
    }

    void U4DEntity::rotateTo(U4DQuaternion& rotation){
        transformation->rotateTo(rotation);
    }

    void U4DEntity::rotateBy(U4DQuaternion& rotation){
        transformation->rotateBy(rotation);
    }

    void U4DEntity::rotateTo(float angle, U4DVector3n& axis){
        transformation->rotateTo(angle,axis);
    }

    void U4DEntity::rotateBy(float angle, U4DVector3n& axis){
        transformation->rotateBy(angle,axis);
    }

    void U4DEntity::rotateTo(float angleX, float angleY, float angleZ){
     
        transformation->rotateTo(angleX,angleY,angleZ);
    }

    void U4DEntity::rotateBy(float angleX, float angleY, float angleZ){
        
        transformation->rotateBy(angleX,angleY,angleZ);
    }

    void U4DEntity::rotateAboutAxis(float angle, U4DVector3n& axisOrientation, U4DVector3n& axisPosition){
        
        transformation->rotateAboutAxis(angle, axisOrientation,axisPosition);
    }

    void U4DEntity::rotateAboutAxis(U4DQuaternion& uOrientation, U4DVector3n& axisPosition){
        
        transformation->rotateAboutAxis(uOrientation, axisPosition);
        
    }

//    void U4DEntity::viewInDirection(U4DVector3n& uDestinationPoint){
//        
//        transformation->viewInDirection(uDestinationPoint);
//        
//    }
    
    
    
    
    void U4DEntity::setZDepth(int uZDepth){
        
        zDepth=uZDepth;
        
    }
    
    int U4DEntity::getZDepth(){
        return zDepth;
        
    }


}
