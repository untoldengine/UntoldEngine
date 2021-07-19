//
//  U4DModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DModel.h"
#include "U4DCamera.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"
#include "U4DMatrix4n.h"
#include "U4DMatrix3n.h"
#include "U4DArmatureData.h"
#include "U4DBoneData.h"
#include "U4DMeshOctreeManager.h"
#include "U4DMeshOctreeNode.h"
#include "Constants.h"
#include "U4DRender3DModel.h"
#include "U4DBoundingVolume.h"
#include "U4DBoundingAABB.h"
#include "U4DResourceLoader.h"
#include "U4DEntityManager.h"
#include "U4DVisibilityDictionary.h"

#pragma mark-set up the body vertices

namespace U4DEngine {
    
    U4DModel::U4DModel():hasMaterial(false),hasTexture(false),hasAnimation(false),hasArmature(false),hasNormalMap(false),enableNormalMap(false),cullingPhaseBoundingVolumeVisibility(false),shaderParameterContainer(10,U4DVector4n(0.0,0.0,0.0,0.0)),classType("U4DModel"){
        
        renderEntity=new U4DRender3DModel(this);
        
        armatureManager=new U4DArmatureData(this);
        
        setEntityType(MODEL);
        
        renderEntity->setPipelineForPass("modelpipeline",U4DEngine::finalPass);
        renderEntity->setPipelineForPass("shadowpipeline",U4DEngine::shadowPass);
        renderEntity->setPipelineForPass("offscreenpipeline",U4DEngine::offscreenPass);
        renderEntity->setPipelineForPass("gbufferpipeline",U4DEngine::gBufferPass);
        
        cullingPhaseBoundingVolume=nullptr;
        
        //set the mesh octree manager to null
        meshOctreeManager=nullptr;
        
    };
    
    U4DModel::~U4DModel(){
        
        delete renderEntity;
        delete cullingPhaseBoundingVolume;
        delete armatureManager;
        delete meshOctreeManager;
        
        U4DVisibilityDictionary *visibilityDict=U4DVisibilityDictionary::sharedInstance();
        visibilityDict->removeFromVisibilityDictionary(getName());
        
    };
    
    U4DModel::U4DModel(const U4DModel& value){
    
    
    };
    
    U4DModel& U4DModel::operator=(const U4DModel& value){
        
        return *this;
    
    };

    
    #pragma mark-draw
    
    void U4DModel::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderEntity->render(uRenderEncoder);
    }

bool U4DModel::loadModel(const char* uModelName){
    
    U4DEngine::U4DResourceLoader *loader=U4DEngine::U4DResourceLoader::sharedInstance();
    
    if (loader->loadAssetToMesh(this, uModelName)) {
        
       //init the culling bounding volume
       initCullingBoundingVolume();
        
       U4DVisibilityDictionary *visibilityDict=U4DVisibilityDictionary::sharedInstance();
        
       visibilityDict->loadIntoVisibilityDictionary(getName(), this);
       
       return true;
        
    }
    
    return false;
}

bool U4DModel::loadAnimationToModel(U4DAnimation *uAnimation, const char* uAnimationName){
    
    U4DEngine::U4DResourceLoader *loader=U4DEngine::U4DResourceLoader::sharedInstance();
    
    if (loader->loadAnimationToMesh(uAnimation,uAnimationName)) {
        
       
       return true;
        
    }
    
    return false;
    
}

bool U4DModel::getBoneRestPose(std::string uBoneName, U4DMatrix4n &uBoneRestPoseMatrix){

    U4DBoneData *rootBone=armatureManager->rootBone;
    
    //check if rootbone exist
    if(rootBone!=nullptr){
        
        //get the bone rest pose space
        U4DDualQuaternion boneRestPoseSpace=rootBone->searchChild(uBoneName)->restAbsolutePoseSpace;
        
        //get the position of the bone
        U4DQuaternion bonePureQuaternion=boneRestPoseSpace.getPureQuaternionPart();
        
        U4DVector3n bonePosition=bonePureQuaternion.v;
        
        //get the final matrix of the bone in rest pose
        uBoneRestPoseMatrix=rootBone->searchChild(uBoneName)->finalSpaceMatrix;
        
        //flip the y and z coordinates to compensate for the different coordinates systems between Blender and the Untold Engine
        //Note that I had to use the location of the rest pose space and use it as the final space matrix location
        uBoneRestPoseMatrix.matrixData[12]=bonePosition.x;
        uBoneRestPoseMatrix.matrixData[13]=bonePosition.z;
        uBoneRestPoseMatrix.matrixData[14]=bonePosition.y;
        
        return true;
    
    }
    
    return false;
    
}

bool U4DModel::getBoneAnimationPose(std::string uBoneName, U4DAnimation *uAnimation, U4DMatrix4n &uBoneAnimationPoseMatrix){
    

    U4DBoneData *rootBone=armatureManager->rootBone;
    
    //check if rootbone exist and animation is currently being played
    if (rootBone!=nullptr && uAnimation->getAnimationIsPlaying()==true) {
        
        //get the bone animation pose space
        U4DDualQuaternion boneAnimationPoseSpace=rootBone->searchChild(uBoneName)->animationPoseSpace;
        
        //get the position of the bone
        U4DQuaternion bonePureQuaternion=boneAnimationPoseSpace.getPureQuaternionPart();
        
        U4DVector3n bonePosition=bonePureQuaternion.v;
        
        //get the final matrix of the bone in animation pose
        uBoneAnimationPoseMatrix=rootBone->searchChild(uBoneName)->finalSpaceMatrix;
        
        //flip the y and z coordinates to compensate for the different coordinates systems between Blender and the Untold Engine
        //Note that I had to use the location of the animation pose space and use it as the final space matrix location
        uBoneAnimationPoseMatrix.matrixData[12]=bonePosition.x;
        uBoneAnimationPoseMatrix.matrixData[13]=bonePosition.z;
        uBoneAnimationPoseMatrix.matrixData[14]=bonePosition.y;
        
        return true;
    
    }
    
    return false;
    
}
    
    void U4DModel::loadIntoVisibilityManager(U4DEntityManager *uEntityManager){
        
        uEntityManager->loadIntoVisibilityManager(this);
    }

    U4DVector3n U4DModel::getModelDimensions(){
        
        return bodyCoordinates.getModelDimension();
    }

    void U4DModel::setNormalMapTexture(std::string uTexture){
        
        textureInformation.setNormalBumpTexture(uTexture);
        
        computeNormalMapTangent();
    }
    
    void U4DModel::setEnableNormalMap(bool uValue){
        
        enableNormalMap=uValue;
        
    }

    void U4DModel::updateAllUniforms(){
        renderEntity->updateAllUniforms();
    }
    
    bool U4DModel::getEnableNormalMap(){
        
        if (enableNormalMap && hasNormalMap) {
            return enableNormalMap;
        }
        
        return false;
        
    }
    
    void U4DModel::setTexture0(std::string uTexture0){
        textureInformation.texture0=uTexture0;
    }
        
    void U4DModel::setTexture1(std::string uTexture1){
        textureInformation.texture1=uTexture1;
    }

    void U4DModel::setRawImageData(std::vector<unsigned char> uRawImageData){
      
        renderEntity->setRawImageData(uRawImageData);
        
    }
        
    void U4DModel::setImageWidth(unsigned int uImageWidth){
        
        renderEntity->setImageWidth(uImageWidth);
        
    }
        
    void U4DModel::setImageHeight(unsigned int uImageHeight){
        
        renderEntity->setImageHeight(uImageHeight);
    
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
        U4DVector3n entityPosition;
        float oneEightyAngle=180.0;
        
        //Get the absolute position
        entityPosition=getAbsolutePosition();
        
        //calculate the forward vector
        U4DVector3n forwardVector=uDestinationPoint-entityPosition;
        
        //create a forward vector that is in the same y-plane as the entity forward vector
        U4DVector3n altPlaneForwardVector=forwardVector;
        
        altPlaneForwardVector.y=getEntityForwardVector().y;
        
        //normalize both vectors
        forwardVector.normalize();
        altPlaneForwardVector.normalize();
        
        //calculate the angle between the entity forward vector and the alternate forward vector
        float angleBetweenEntityForwardAndAltForward=getEntityForwardVector().angle(altPlaneForwardVector);
        
        //calculate the rotation axis between forward vectors
        U4DVector3n rotationAxisOfEntityAndAltForward=getEntityForwardVector().cross(altPlaneForwardVector);
        
        //if angle is 180 or -180 it means that both vectors are pointing opposite to each other.
        //this means that there is no rotation axis. so set the Up Vector as the rotation axis
        
        //Get the absolute value of the angle, so we can properly test it.
        float nAngle=fabs(angleBetweenEntityForwardAndAltForward);
        
        if ((fabs(nAngle - oneEightyAngle) <= U4DEngine::zeroEpsilon * std::max(1.0f, std::max(nAngle, zeroEpsilon)))) {
            
            rotationAxisOfEntityAndAltForward=upVector;
            angleBetweenEntityForwardAndAltForward=180.0;
            
        }
        
        rotationAxisOfEntityAndAltForward.normalize();
        
        U4DQuaternion rotationAboutEntityAndAltForward(angleBetweenEntityForwardAndAltForward, rotationAxisOfEntityAndAltForward);
        
        rotateTo(rotationAboutEntityAndAltForward);
        
        //calculate the angle between the forward vector and the alternate forward vector
        float angleBetweenForwardVectorAndAltForward=forwardVector.angle(altPlaneForwardVector);
        
        //calculate the rotation axis between the forward vectors
        U4DVector3n rotationAxisOfForwardVectorAndAltForward=altPlaneForwardVector.cross(forwardVector);
        
        rotationAxisOfForwardVectorAndAltForward.normalize();
        
        U4DQuaternion rotationAboutForwardVectorAndAltForward(angleBetweenForwardVectorAndAltForward,rotationAxisOfForwardVectorAndAltForward);
        
        rotateBy(rotationAboutForwardVectorAndAltForward);
        
    }
    
    U4DDualQuaternion U4DModel::getBoneAnimationSpace(std::string uName){
        
        U4DBoneData *bone=armatureManager->rootBone->searchChild(uName);
        
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
    
        renderEntity->setIsWithinFrustum(uValue);
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

    void U4DModel::updateShaderParameterContainer(int uPosition, U4DVector4n &uParamater){
        
        if (uPosition<shaderParameterContainer.size()) {
            
            shaderParameterContainer.at(uPosition)=uParamater;
            
        }
        
    }

    std::vector<U4DVector4n> U4DModel::getModelShaderParameterContainer(){
        return shaderParameterContainer;
    }

    void U4DModel::enableMeshManager(int uSubDivisions){
        
        if(meshOctreeManager==nullptr){
            
            //create an instance of the octree mesh manager
            meshOctreeManager=new U4DMeshOctreeManager(this);
            
            //build the octree for the 3D model
            meshOctreeManager->buildOctree(uSubDivisions); 
            
        }
    }

    U4DMeshOctreeManager *U4DModel::getMeshOctreeManager(){
        
        return meshOctreeManager;
        
    }

    void U4DModel::setClassType(std::string uClassType){
         
        classType=uClassType;
        
    }

    std::string U4DModel::getClassType(){
        
        return classType;
    }

    void U4DModel::setAssetReferenceName(std::string uAssetReferenceName){
        assetReferenceName=uAssetReferenceName;
    }

    std::string U4DModel::getAssetReferenceName(){
        return assetReferenceName;
    }
    
}



