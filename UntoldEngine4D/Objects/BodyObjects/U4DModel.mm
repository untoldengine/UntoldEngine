//
//  U4DModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DModel.h"
#include "U4DCamera.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"
#include "U4DMatrix4n.h"
#include "U4DMatrix3n.h"
#include "U4DArmatureData.h"
#include "U4DBoneData.h"
#include "Constants.h"
#include "U4DRender3DModel.h"
#include "U4DBoundingVolume.h"
#include "U4DBoundingAABB.h"

#pragma mark-set up the body vertices

namespace U4DEngine {
    
    U4DModel::U4DModel():hasMaterial(false),hasTexture(false),hasAnimation(false),hasArmature(false),enableShadow(false),hasNormalMap(false),cullingPhaseBoundingVolumeVisibility(false),enableModelVisibility(true){
        
        renderManager=new U4DRender3DModel(this);
        
        armatureManager=new U4DArmatureData(this);
        
        setShader("vertexModelShader", "fragmentModelShader");
        
        setEntityType(MODEL);
        
    };
    
    U4DModel::~U4DModel(){
        
        delete renderManager;
        delete armatureManager;
    };
    
    U4DModel::U4DModel(const U4DModel& value){
    
    
    };
    
    U4DModel& U4DModel::operator=(const U4DModel& value){
        
        return *this;
    
    };

    
    #pragma mark-draw
    
    void U4DModel::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
    }
    
    void U4DModel::renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){
        
        renderManager->renderShadow(uRenderShadowEncoder,uShadowTexture);
        
    }
    
    void U4DModel::setNormalMapTexture(std::string uTexture){
        
        textureInformation.setNormalBumpTexture(uTexture);
        
        computeNormalMapTangent();
    }
    
    void U4DModel::setEnableNormalMap(bool uValue){
        
        enableNormalMap=uValue;
        
    }
    
    bool U4DModel::getEnableNormalMap(){
        
        if (enableNormalMap && hasNormalMap) {
            return enableNormalMap;
        }
        
        return false;
        
    }
    
    void U4DModel::setEnableShadow(bool uValue){
        enableShadow=uValue;
    }
    
    bool U4DModel::getEnableShadow(){
        return enableShadow;
    }
    
    void U4DModel::setHasNormalMap(bool uValue){
        
        hasNormalMap=uValue;
        setEnableNormalMap(true);
    }
    
    bool U4DModel::getHasNormalMap(){
        return hasNormalMap;
    }
    
    void U4DModel::setHasMaterial(bool uValue){
        
        hasMaterial=uValue;
    }
    
    void U4DModel::setHasTexture(bool uValue){
        hasTexture=uValue;
    }
    
    void U4DModel::setHasAnimation(bool uValue){
        hasAnimation=uValue;
    }
    
    void U4DModel::setHasArmature(bool uValue){
        hasArmature=uValue;
    }
    
    bool U4DModel::getHasMaterial(){
        return hasMaterial;
    }
    
    bool U4DModel::getHasTexture(){
        return hasTexture;
    }
    
    bool U4DModel::getHasAnimation(){
        return hasAnimation;
    }
    
    bool U4DModel::getHasArmature(){
        return hasArmature;
    }
    
    U4DVector3n U4DModel::getViewInDirection(){
        
        //get forward vector
        U4DVector3n forward=getEntityForwardVector();
        
        //get the entity rotation matrix
        U4DMatrix3n orientationMatrix=getLocalMatrixOrientation();
        
        return orientationMatrix*forward;
        
    }
    
    void U4DModel::viewInDirection(U4DVector3n& uDestinationPoint){
        
        U4DVector3n upVector(0,1,0);
        float oneEightyAngle=180.0;
        U4DVector3n entityPosition;
        
        entityPosition=getAbsolutePosition();
        
        //calculate the forward vector
        U4DVector3n forwardVector=uDestinationPoint-entityPosition;
        
        //calculate the angle
        float angle=getEntityForwardVector().angle(forwardVector);
        
        //calculate the rotation axis
        U4DVector3n rotationAxis=getEntityForwardVector().cross(forwardVector);
        
        //if angle is 180 it means that both vectors are pointing opposite to each other.
        //this means that there is no rotation axis. so set the Up Vector as the rotation axis
        
        if ((fabs(angle - oneEightyAngle) <= U4DEngine::zeroEpsilon * std::max(1.0f, std::max(angle, zeroEpsilon)))) {
            
            rotationAxis=upVector;
            angle=180.0;
            
        }
        
        rotationAxis.normalize();
        
        U4DQuaternion rotationQuaternion(angle,rotationAxis);
        
        rotateTo(rotationQuaternion);
        
    }
    
    U4DDualQuaternion U4DModel::getBoneAnimationSpace(std::string uName){
        
        U4DBoneData *bone=armatureManager->rootBone->searchChildrenBone(uName);
        
        return bone->getBoneAnimationPoseSpace();
        
    }
    
    void U4DModel::computeNormalMapTangent(){
        
        if (bodyCoordinates.uVContainer.size()!=0) {
            
            U4DVector3n *tan1=new U4DVector3n[2*bodyCoordinates.verticesContainer.size()];
            U4DVector3n *tan2=new U4DVector3n[2*bodyCoordinates.verticesContainer.size()];
            
            for (int i=0; i<bodyCoordinates.indexContainer.size();i++) {
                
                int i1=bodyCoordinates.indexContainer.at(i).x;
                int i2=bodyCoordinates.indexContainer.at(i).y;
                int i3=bodyCoordinates.indexContainer.at(i).z;
                
                
                U4DVector3n v1=bodyCoordinates.verticesContainer.at(i1);
                
                
                U4DVector3n v2=bodyCoordinates.verticesContainer.at(i2);
                
                
                U4DVector3n v3=bodyCoordinates.verticesContainer.at(i3);
                
                //get the uv
                
                U4DVector2n w1=bodyCoordinates.uVContainer.at(i1);
                
                
                U4DVector2n w2=bodyCoordinates.uVContainer.at(i2);
                
                
                U4DVector2n w3=bodyCoordinates.uVContainer.at(i3);
                
                float x1=v2.x-v1.x;
                float x2=v3.x-v1.x;
                float y1=v2.y-v1.y;
                float y2=v3.y-v1.y;
                float z1=v2.z-v1.z;
                float z2= v3.z-v1.z;
                
                float s1=w2.x-w1.x;
                float s2=w3.x-w1.x;
                float t1=w2.y-w1.y;
                float t2=w3.y-w1.y;
                
                float r=1.0/(s1*t2-s2*t1);
                U4DVector3n sdir((t2*x1-t1*x2)*r,(t2*y1-t1*y2)*r,(t2*z1-t1*z2)*r);
                U4DVector3n tdir((s1*x2-s2*x1)*r,(s1*y2-s2*y1)*r,(s1*z2-s2*z1)*r);
                
                tan1[i1]+=sdir;
                tan1[i2]+=sdir;
                tan1[i3]+=sdir;
                
                tan2[i1]+=tdir;
                tan2[i2]+=tdir;
                tan2[i3]+=tdir;
                
                
            }
            
            for (int a=0; a<bodyCoordinates.normalContainer.size(); a++) {
                
                
                
                U4DVector3n n=bodyCoordinates.normalContainer.at(a);
                
                U4DVector3n t=tan1[a];
                
                //Gram-Schmidt orthogonalize
                
                U4DVector3n nt=(t-n*n.dot(t));
                nt.normalize();
                
                //calculate handedness
                
                //h.w=(n.cross(t).dot(tan2[a])<0.0) ? -1.0:1.0;
                float handedness=((n.cross(t)).dot(tan2[a])<0.0) ? -1.0:1.0;
                
                U4DVector4n h(nt.x,nt.y,nt.z,handedness);
                
                bodyCoordinates.addTangetDataToContainer(h);
                
            }
            
            delete[] tan1;
            delete[] tan2;
            
        }
        
    }
    
    void U4DModel::setModelVisibility(bool uValue){
    
        renderManager->setIsWithinFrustum(uValue);
    }

    void U4DModel::initCullingBoundingVolume(){
        
        //Get body dimensions
        float xDimension=bodyCoordinates.getModelDimension().x;
        float yDimension=bodyCoordinates.getModelDimension().y;
        float zDimension=bodyCoordinates.getModelDimension().z;
        
        //get min and max points to create the AABB
        U4DPoint3n minPoints(-xDimension/2.0,-yDimension/2.0,-zDimension/2.0);
        U4DPoint3n maxPoints(xDimension/2.0,yDimension/2.0,zDimension/2.0);
        
        //create a AABB culling bounding volume
        cullingPhaseBoundingVolume=new U4DBoundingAABB();
        
        //calculate the culling AABB
        cullingPhaseBoundingVolume->computeBoundingVolume(minPoints, maxPoints);
        
    }
    
    void U4DModel::updateCullingPhaseBoundingVolumeSpace(){
        
        //update the bounding volume with the model current space dual quaternion (rotation and translation)
        cullingPhaseBoundingVolume->setLocalSpace(absoluteSpace);
    }
    
    U4DBoundingVolume* U4DModel::getCullingPhaseBoundingVolume(){
        
        //update the broad phase bounding volume space
        updateCullingPhaseBoundingVolumeSpace();
        
        return cullingPhaseBoundingVolume;
        
    }
    
    void U4DModel::setCullingPhaseBoundingVolumeVisibility(bool uValue){
        
        cullingPhaseBoundingVolumeVisibility=true;
    }
    
    bool U4DModel::getCullingPhaseBoundingVolumeVisibility(){
        
        return cullingPhaseBoundingVolumeVisibility;
        
    }
    
    void U4DModel::setEnableModelVisibility(bool uValue){
        
        enableModelVisibility=uValue;
    }
    
    bool U4DModel::getEnableModelVisibility(){
        return enableModelVisibility;
    }
}



