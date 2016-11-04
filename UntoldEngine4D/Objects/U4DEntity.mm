//
//  U4DEntity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DEntity.h"
#include "U4DQuaternion.h"
#include "U4DMatrix4n.h"
#include "U4DMatrix3n.h"
#include "U4DTransformation.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
    U4DEntity::U4DEntity():localOrientation(0,0,0),localPosition(0,0,0),entityForwardVector(0,0,-1),parent(nullptr),next(nullptr){
        
        prevSibling=this;
        lastDescendant=this;
        
        transformation=new U4DTransformation(this);
    
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
        
        if (parent!=NULL) {
            space=absoluteSpace;
        }else{
            space=getLocalSpace();
        }
        
        return space;
    }

    U4DQuaternion U4DEntity::getAbsoluteSpaceOrientation(){
        
        U4DDualQuaternion space;
        
        if (parent!=NULL) {
            space=getLocalSpace()*parent->getLocalSpace();
        }else{
            space=getLocalSpace();
        }
        
        return space.getRealQuaternionPart();
    }

    U4DQuaternion U4DEntity::getAbsoluteSpacePosition(){

        U4DDualQuaternion space;
        
        if (parent!=NULL) {
            space=getLocalSpace()*parent->getLocalSpace();
        
        }else{
            
            space=getLocalSpace();
        }
        
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
        
        U4DDualQuaternion space;
        
        if (parent!=NULL) {
        
            space=getLocalSpace()*parent->getLocalSpace();
        
        }else{
        
            space=getLocalSpace();
        
        }
        
        
        U4DQuaternion orientation=space.getRealQuaternionPart();
        
        return orientation.transformQuaternionToEulerAngles();
        
    }

    U4DVector3n U4DEntity::getAbsolutePosition(){
     
        U4DDualQuaternion space;
        
        if (parent!=NULL) {
            space=getLocalSpace()*parent->getLocalSpace();
        }else{
            space=getLocalSpace();
        }
        
        U4DQuaternion position=space.getPureQuaternionPart();
        
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
    //scenegraph methods
    void U4DEntity::addChild(U4DEntity *uChild){
        
        if (uChild!=NULL) {
            
            U4DEntity* lastAddedChild=getFirstChild();
            
            if(lastAddedChild==0){ //add as first child
                
                uChild->parent=this;
                
                uChild->lastDescendant->next=lastDescendant->next;
                
                lastDescendant->next=uChild;
                
                uChild->prevSibling=getLastChild();
                
                if (isLeaf()) {
                    
                    next=uChild;
                    
                }
                
                getFirstChild()->prevSibling=uChild;
                
                changeLastDescendant(uChild->lastDescendant);
                
                
            }else{
                
                uChild->parent=lastAddedChild->parent;
                
                uChild->prevSibling=lastAddedChild->prevSibling;
                
                uChild->lastDescendant->next=lastAddedChild;
                
                if (lastAddedChild->parent->next==lastAddedChild) {
                    lastAddedChild->parent->next=uChild;
                }else{
                    lastAddedChild->prevSibling->lastDescendant->next=uChild;
                }
                
                lastAddedChild->prevSibling=uChild;
                
            }
            
        }else{
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("Error: An entity seems to be un-initialized. This entity was not loaded into the scenegraph");
        }
        
    }

    void U4DEntity::removeChild(U4DEntity *uChild){
        
        U4DEntity* sibling = uChild->getNextSibling();
        
        if (sibling)
            sibling->prevSibling = uChild->prevSibling;
        else
            getFirstChild()->prevSibling = uChild->prevSibling;
        
        if (lastDescendant == uChild->lastDescendant)
            changeLastDescendant(uChild->prevInPreOrderTraversal());
        
        if (next == uChild)	// deleting first child?
            next = uChild->lastDescendant->next;
        else
            uChild->prevSibling->lastDescendant->next = uChild->lastDescendant->next;
        
    }

    U4DEntity *U4DEntity::prevInPreOrderTraversal(){
        
        U4DEntity* prev = 0;
        if (parent)
        {
            if (parent->next == this)
                prev = parent;
            else
                prev = prevSibling->lastDescendant;
        }
        return prev;
    }

    U4DEntity *U4DEntity::nextInPreOrderTraversal(){
        return next;
    }

    U4DEntity *U4DEntity::getFirstChild(){
        
        U4DEntity* child=NULL;
        if(next && (next->parent==this)){
            child=next;
        }
        
        return child;
    }

    U4DEntity *U4DEntity::getLastChild(){
        
        U4DEntity *child=getFirstChild();
        
        if(child){
            child=child->prevSibling;
        }
        
        return child;
    }

    U4DEntity *U4DEntity::getNextSibling(){
        
        U4DEntity* sibling = lastDescendant->next;
        if (sibling && (sibling->parent != parent))
            sibling = 0;
        return sibling;
    }


    U4DEntity *U4DEntity::getPrevSibling(){
        U4DEntity* sibling = 0;
        if (parent && (parent->next != this))
            sibling =prevSibling;
        return sibling;
    }

    void U4DEntity::changeLastDescendant(U4DEntity *uNewLastDescendant){
        
        U4DEntity *oldLast=lastDescendant;
        U4DEntity *ancestor=this;
        
        do{
            ancestor->lastDescendant=uNewLastDescendant;
            ancestor=ancestor->parent;
        }while (ancestor && (ancestor->lastDescendant==oldLast));
        
    }

    bool U4DEntity::isRoot(){
        
        bool value=false;
        
        if (parent==0) {
            
            value=true;
            
        }
        
        return value;
    }

    bool U4DEntity::isLeaf(){
        
        return (lastDescendant==this);
        
    }
    
    U4DEntity* U4DEntity::getParent(){
        
        return parent;
    }
    
    U4DEntity* U4DEntity::getRootParent(){
        
        U4DEntity *rootParent=parent;
        
        while (rootParent->isRoot()==false) {
            
            rootParent=rootParent->parent;
        }
        
        return rootParent;
    }

    U4DEntity *U4DEntity::searchChild(std::string uName){
        
        //get the first child
        U4DEntity* child=next;
        U4DEntity* childWithName=nullptr;
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        while (child!=NULL) {
            
            if (child->getName().compare(uName)!=0) {
                
                child=child->next;
                
            }else if (child->getName().compare(uName)==0){
                
                childWithName=child;
                
                break;
                
            }
            
        }
        
        if (childWithName==nullptr) {
            
            logger->log("Error: Child with name %s was not found.", uName.c_str());
            
        }
        
        return childWithName;
        
    }
}
