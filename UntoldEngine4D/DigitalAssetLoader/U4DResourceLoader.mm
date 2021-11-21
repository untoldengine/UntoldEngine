//
//  U4DResourceLoader.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DResourceLoader.h"
#include "CommonProtocols.h"
#include "Constants.h"
#include "U4DRenderEntity.h"
#include "U4DModel.h"
#include "U4DMatrix4n.h"
#include "U4DVector4n.h"
#include "U4DSegment.h"
#include "U4DArmatureData.h"
#include "U4DBoneData.h"
#include "U4DAnimation.h"
#include "U4DParticleSystem.h"
#include "U4DLogger.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DText.h"
#include "U4DPointLight.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DWorld.h"

namespace U4DEngine {

    U4DResourceLoader::U4DResourceLoader(){
        
    }

    U4DResourceLoader::~U4DResourceLoader(){
        
    }

    U4DResourceLoader* U4DResourceLoader::instance=0;

    U4DResourceLoader* U4DResourceLoader::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DResourceLoader();
        }
        
        return instance;
    }

    bool U4DResourceLoader::loadSceneData(std::string uFilepath){
        
        std::ifstream file(uFilepath, std::ios::in | std::ios::binary );
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(!file){
            
            logger->log("Error: Couldn't load the Scene Asset File, No file %s exist.",uFilepath.c_str());
            
            return false;
            
        }
        
        file.seekg(0);
        
        //READ NUMBER OF MESHES IN SCENE
        int numberOfMeshesSize=0;
        file.read((char*)&numberOfMeshesSize,sizeof(int));
        
        for(int i=0;i<numberOfMeshesSize;i++){
        
        MODELRAW uModel;
        
        //READ NAME
         size_t modelNamelen=0;
         file.read((char*)&modelNamelen,sizeof(modelNamelen));
         uModel.name.resize(modelNamelen);
         file.read((char*)&uModel.name[0],modelNamelen);
         
         //READ VERTICES
         int verticesSize=0;
         file.read((char*)&verticesSize,sizeof(int));
         std::vector<float> tempVertices(verticesSize,0);
         
         //copy temp to model2
         uModel.vertices=tempVertices;
         file.read((char*)&uModel.vertices[0], verticesSize*sizeof(float));
         
         //READ NORMALS
         int normalsSize=0;
         file.read((char*)&normalsSize,sizeof(int));
         std::vector<float> tempNormals(normalsSize,0);
         
         //copy temp to model2
         uModel.normals=tempNormals;
         file.read((char*)&uModel.normals[0], normalsSize*sizeof(float));

         //READ UVs
         int uvSize=0;
         file.read((char*)&uvSize,sizeof(int));
         std::vector<float> tempUV(uvSize,0);
         
         //copy temp to model2
         uModel.uv=tempUV;
         file.read((char*)&uModel.uv[0], uvSize*sizeof(float));
         
         //READ INDEX
         int indexSize=0;
         file.read((char*)&indexSize,sizeof(int));
         std::vector<int> tempIndex(indexSize,0);
         
         //copy temp to model2
         uModel.index=tempIndex;
         file.read((char*)&uModel.index[0], indexSize*sizeof(int));
        
         
         //READ CONVEX HULL INFO
         CONVEXHULLRAW convexHullRaw;
        
         convexHullRaw.name=uModel.name;
         
         //READ CONVEX HULL VERTICES
         int convexHullVerticesSize=0;
         file.read((char*)&convexHullVerticesSize,sizeof(int));
         std::vector<float> tempConvexHullVertices(convexHullVerticesSize,0);
         
         //copy temp to model2
         convexHullRaw.convexHullVertices=tempConvexHullVertices;
         file.read((char*)&convexHullRaw.convexHullVertices[0], convexHullVerticesSize*sizeof(float));
         
         //READ CONVEX HULL EDGES
         int convexHullEdgesSize=0;
         file.read((char*)&convexHullEdgesSize,sizeof(int));
         std::vector<float> tempConvexHullEdges(convexHullEdgesSize,0);
         
         //copy temp to model2
         convexHullRaw.convexHullEdges=tempConvexHullEdges;
         file.read((char*)&convexHullRaw.convexHullEdges[0], convexHullEdgesSize*sizeof(float));
         
         //READ CONVEX HULL FACES
         int convexHullFacesSize=0;
         file.read((char*)&convexHullFacesSize,sizeof(int));
         std::vector<float> tempConvexHullFaces(convexHullFacesSize,0);
         
         //copy temp to model2
         convexHullRaw.convexHullFaces=tempConvexHullFaces;
         file.read((char*)&convexHullRaw.convexHullFaces[0], convexHullFacesSize*sizeof(float));
         
         //load convex data into container
         convexHullContainer.push_back(convexHullRaw);
            
         //READ MATERIAL INDEX
         int materialIndexSize=0;
         file.read((char*)&materialIndexSize,sizeof(int));
         std::vector<int> tempMaterialIndex(materialIndexSize,0);
         
         //copy temp to model2
         uModel.materialIndex=tempMaterialIndex;
         file.read((char*)&uModel.materialIndex[0], materialIndexSize*sizeof(int));
         
         
         //READ DIFFUSE COLOR
         int diffuseColorSize=0;
         file.read((char*)&diffuseColorSize,sizeof(int));
         std::vector<float> tempDiffuseColor(diffuseColorSize,0);
         
         //copy temp to model2
         uModel.diffuseColor=tempDiffuseColor;
         file.read((char*)&uModel.diffuseColor[0], diffuseColorSize*sizeof(float));
         
         
         //READ SPECULAR COLOR
         int specularColorSize=0;
         file.read((char*)&specularColorSize,sizeof(int));
         std::vector<float> tempSpecularColor(specularColorSize,0);
         
         //copy temp to model2
         uModel.specularColor=tempSpecularColor;
         file.read((char*)&uModel.specularColor[0], specularColorSize*sizeof(float));
         
         
         //READ DIFFUSE INTENSITY
         int diffuseIntensitySize=0;
         file.read((char*)&diffuseIntensitySize,sizeof(int));
         std::vector<float> tempDiffuseIntensity(diffuseIntensitySize,0);
         
         //copy temp to model2
         uModel.diffuseIntensity=tempDiffuseIntensity;
         file.read((char*)&uModel.diffuseIntensity[0], diffuseIntensitySize*sizeof(float));
         
         
         //READ SPECULAR INTENSITY
         int specularIntensitySize=0;
         file.read((char*)&specularIntensitySize,sizeof(int));
         std::vector<float> tempSpecularIntensity(specularIntensitySize,0);
         
         //copy temp to model2
         uModel.specularIntensity=tempSpecularIntensity;
         file.read((char*)&uModel.specularIntensity[0], specularIntensitySize*sizeof(float));
         
         
         //READ SPECULAR HARDNESS
         int specularHardnessSize=0;
         file.read((char*)&specularHardnessSize,sizeof(int));
         std::vector<float> tempSpecularHardness(specularHardnessSize,0);
         
         //copy temp to model2
         uModel.specularHardness=tempSpecularHardness;
         file.read((char*)&uModel.specularHardness[0], specularHardnessSize*sizeof(float));
         
         
         //READ TEXTURE IMAGE
         size_t textureNamelen=0;
         file.read((char*)&textureNamelen,sizeof(textureNamelen));
         uModel.textureNameSize=textureNamelen;
         uModel.textureImage.resize(textureNamelen);
         file.read((char*)&uModel.textureImage[0],textureNamelen);
            
        
         //READ LOCAL MATRIX
         int localMatrixSize=0;
         file.read((char*)&localMatrixSize,sizeof(int));
         std::vector<float> tempLocalMatrix(localMatrixSize,0);
         
         //copy temp to model2
         uModel.localMatrix=tempLocalMatrix;
         file.read((char*)&uModel.localMatrix[0], localMatrixSize*sizeof(float));
         
         
         //READ DIMENSION
         int dimensionSize=0;
         file.read((char*)&dimensionSize,sizeof(int));
         std::vector<float> tempDimension(dimensionSize,0);
         
         //copy temp to model2
         uModel.dimension=tempDimension;
         file.read((char*)&uModel.dimension[0], dimensionSize*sizeof(float));
         
         
         //READ MESH VERTICES
         int meshVerticesSize=0;
         file.read((char*)&meshVerticesSize,sizeof(int));
         std::vector<float> tempMeshVertices(meshVerticesSize,0);
         
         //copy temp to model2
         uModel.meshVertices=tempMeshVertices;
         file.read((char*)&uModel.meshVertices[0], meshVerticesSize*sizeof(float));
         
         //READ MESH EDGES INDEX
         int meshEdgesIndexSize=0;
         file.read((char*)&meshEdgesIndexSize,sizeof(int));
         std::vector<int> tempMeshEdges(meshEdgesIndexSize,0);
         
         //copy temp to model2
         uModel.meshEdgesIndex=tempMeshEdges;
         file.read((char*)&uModel.meshEdgesIndex[0], meshEdgesIndexSize*sizeof(int));
         
         //READ MESH FACES INDEX
         int meshFacesIndexSize=0;
         file.read((char*)&meshFacesIndexSize,sizeof(int));
         std::vector<int> tempMeshFaceIndex(meshFacesIndexSize,0);
         
         //copy temp to model2
         uModel.meshFacesIndex=tempMeshFaceIndex;
         file.read((char*)&uModel.meshFacesIndex[0], meshFacesIndexSize*sizeof(int));
        
        //READ ARMATURE
        //READ NUMBER OF BONES
        int numberOfBonesSize=0;
        file.read((char*)&numberOfBonesSize,sizeof(int));
        file.read((char*)&uModel.armature.numberOfBones, sizeof(numberOfBonesSize));
        
        if(numberOfBonesSize>0){
            
            //READ BIND SHAPE MATRIX
            int bindShapeMatrixSize=0;
            file.read((char*)&bindShapeMatrixSize,sizeof(int));
            std::vector<float> tempBindShapeMatrix(bindShapeMatrixSize,0);
            
            //copy temp to model2
            uModel.armature.bindShapeMatrix=tempBindShapeMatrix;
            file.read((char*)&uModel.armature.bindShapeMatrix[0], bindShapeMatrixSize*sizeof(float));
            
            //READ BONES
            
            for(int i=0;i<numberOfBonesSize;i++){
                
                BONESRAW bones;

                //name
                size_t modelBoneNamelen=0;
                file.read((char*)&modelBoneNamelen,sizeof(modelBoneNamelen));
                bones.name.resize(modelBoneNamelen);
                file.read((char*)&bones.name[0],modelBoneNamelen);
                
                //parent
                size_t modelBoneParentNamelen=0;
                file.read((char*)&modelBoneParentNamelen,sizeof(modelBoneParentNamelen));
                bones.parent.resize(modelBoneParentNamelen);
                file.read((char*)&bones.parent[0],modelBoneParentNamelen);
                
                //local matrix
                int boneLocalMatrixSize=0;
                file.read((char*)&boneLocalMatrixSize,sizeof(int));
                std::vector<float> tempBoneLocalMatrix(boneLocalMatrixSize,0);
               
                //copy temp to model2
                bones.localMatrix=tempBoneLocalMatrix;
                file.read((char*)&bones.localMatrix[0], boneLocalMatrixSize*sizeof(float));
                
                //bind pose matrix
                int boneBindPoseMatrixSize=0;
                file.read((char*)&boneBindPoseMatrixSize,sizeof(int));
                std::vector<float> tempBoneBindPoseMatrix(boneBindPoseMatrixSize,0);

                //copy temp to model2
                bones.bindPoseMatrix=tempBoneBindPoseMatrix;
                file.read((char*)&bones.bindPoseMatrix[0], boneBindPoseMatrixSize*sizeof(float));
                
                //inverse pose matrix
                int boneInversePoseMatrixSize=0;
                file.read((char*)&boneInversePoseMatrixSize,sizeof(int));
                std::vector<float> tempBoneInversePoseMatrix(boneInversePoseMatrixSize,0);

                //copy temp to model2
                bones.inversePoseMatrix=tempBoneInversePoseMatrix;
                file.read((char*)&bones.inversePoseMatrix[0], boneInversePoseMatrixSize*sizeof(float));
                
                //rest pose matrix
                int boneRestPoseMatrixSize=0;
                file.read((char*)&boneRestPoseMatrixSize,sizeof(int));
                std::vector<float> tempBoneRestPoseMatrix(boneRestPoseMatrixSize,0);

                //copy temp to model2
                bones.restPoseMatrix=tempBoneRestPoseMatrix;
                file.read((char*)&bones.restPoseMatrix[0], boneRestPoseMatrixSize*sizeof(float));
                
                //vertex weights
                int boneVertexWeightsSize=0;
                file.read((char*)&boneVertexWeightsSize,sizeof(int));
                std::vector<float> tempBoneVertexWeights(boneVertexWeightsSize,0);

                //copy temp to model2
                bones.vertexWeights=tempBoneVertexWeights;
                file.read((char*)&bones.vertexWeights[0], boneVertexWeightsSize*sizeof(float));
                
                uModel.armature.bones.push_back(bones);
                
            }
        }
        
        //load model to container
        modelsContainer.push_back(uModel);
            
        }
        
        logger->log("Success: Scene Asset File %s succesfully Loaded.",uFilepath.c_str());
        
        return true;
        
    }


    bool U4DResourceLoader::loadAnimationData(std::string uFilepath){
        
        std::ifstream file(uFilepath, std::ios::in | std::ios::binary );
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(!file){
            
            logger->log("Error: Couldn't load the Animation Asset File, No file %s exist.",uFilepath.c_str());
            
            return false;
            
        }
        
        file.seekg(0);
        
        ANIMATIONSRAW animation;
        
        //READ ANIMATION NAME
        size_t animNamelen=0;
        file.read((char*)&animNamelen,sizeof(animNamelen));
        animation.name.resize(animNamelen);
        file.read((char*)&animation.name[0],animNamelen);
        
        
        //ANIMATION TRANSFORM
        int poseTransformSize=0;
        file.read((char*)&poseTransformSize,sizeof(int));
        std::vector<float> tempPoseTransform(poseTransformSize,0);
        
        //copy temp to anim2
        animation.poseTransform=tempPoseTransform;
        file.read((char*)&animation.poseTransform[0], poseTransformSize*sizeof(float));
        
        //FPS
        float fpsSize=0;
        file.read((char*)&fpsSize,sizeof(float));
        file.read((char*)&animation.fps, sizeof(fpsSize));
        
        //KEYFRAME COUNT
        int keyframeCountSize=0;
        file.read((char*)&keyframeCountSize,sizeof(int));
        file.read((char*)&animation.keyframeCount, sizeof(keyframeCountSize));
        
        for (int i=0; i<keyframeCountSize; i++) {
        
            KEYFRAMERAW keyframe;
            
            //TIME
            float timeSize=0;
            file.read((char*)&timeSize,sizeof(float));
            file.read((char*)&keyframe.time, sizeof(timeSize));
            
            //BONE COUNT
            int boneCountSize=0;
            file.read((char*)&boneCountSize,sizeof(int));
            file.read((char*)&keyframe.boneCount, sizeof(boneCountSize));
            
            for (int j=0; j<boneCountSize; j++) {
                
                ANIMPOSERAW animpose;
                
                //NAME
                size_t animPoseBoneNamelen=0;
                file.read((char*)&animPoseBoneNamelen,sizeof(animPoseBoneNamelen));
                animpose.boneName.resize(animPoseBoneNamelen);
                file.read((char*)&animpose.boneName[0],animPoseBoneNamelen);
                
                //BONE POSE MATRIX
                int bonePoseMatrixSize=0;
                file.read((char*)&bonePoseMatrixSize,sizeof(int));
                std::vector<float> tempBonePoseMatrix(bonePoseMatrixSize,0);
                
                //copy temp to anim2
                animpose.poseMatrix=tempBonePoseMatrix;
                file.read((char*)&animpose.poseMatrix[0], bonePoseMatrixSize*sizeof(float));
                
                keyframe.animPoseMatrix.push_back(animpose);
                
            }
            
            animation.keyframes.push_back(keyframe);
        }
        
        animationsContainer.push_back(animation);
        
        logger->log("Success: Animation Asset File %s succesfully Loaded.",uFilepath.c_str());
        
        return true;
        
    }

    bool U4DResourceLoader::loadTextureData(std::string uFilepath){
        
        std::ifstream file(uFilepath, std::ios::in | std::ios::binary );
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(!file){
            
            logger->log("Error: Couldn't load the Texture Asset File, No file %s exist.",uFilepath.c_str());
            
            return false;
            
        }
        
        file.seekg(0);
        
        TEXTURESRAW texture;
        
        //READ NUMBER OF TEXTURES
        int numberOfTexturesSize=0;
        file.read((char*)&numberOfTexturesSize,sizeof(int));
        
        for(int i=0;i<numberOfTexturesSize;i++){
            
            //NAME
            size_t textureNamelen=0;
            file.read((char*)&textureNamelen,sizeof(textureNamelen));
            texture.name.resize(textureNamelen);
            file.read((char*)&texture.name[0],textureNamelen);
            
            //WIDTH
            float widthSize=0;
            file.read((char*)&widthSize,sizeof(float));
            file.read((char*)&texture.width, sizeof(widthSize));
            
            //HEIGHT
            float heightSize=0;
            file.read((char*)&heightSize,sizeof(float));
            file.read((char*)&texture.height, sizeof(heightSize));
            
            //IMAGE
            int imageSize=0;
            file.read((char*)&imageSize,sizeof(int));
            std::vector<unsigned char> tempImage(imageSize,0);
            
            //copy temp to model2
            texture.image=tempImage;
            file.read((char*)&texture.image[0], imageSize*sizeof(unsigned char));
            
            texturesContainer.push_back(texture);
            
        }
        
        logger->log("Success: Texture Asset File %s succesfully Loaded.",uFilepath.c_str());
        
        return true;
        
    }

    bool U4DResourceLoader::loadParticleData(std::string uFilepath){
        
        std::ifstream file(uFilepath, std::ios::in | std::ios::binary );
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(!file){
            
            logger->log("Error: Couldn't load the Particle Asset File, No file %s exist.",uFilepath.c_str());
            
            return false;
            
        }
        
        file.seekg(0);
        
        PARTICLESRAW particle;
        
        //READ NAME
        size_t particleNamelen=0;
        file.read((char*)&particleNamelen,sizeof(particleNamelen));
        particle.name.resize(particleNamelen);
        file.read((char*)&particle.name[0],particleNamelen);
        
        //READ position variance
        int positionVarianceSize=0;
        file.read((char*)&positionVarianceSize,sizeof(int));
        std::vector<float> tempPositionVariance(positionVarianceSize,0);
        
        //copy temp to position
        particle.positionVariance=tempPositionVariance;
        file.read((char*)&particle.positionVariance[0], positionVarianceSize*sizeof(float));
        
        //speed
        float speedSize=0;
        file.read((char*)&speedSize,sizeof(float));
        file.read((char*)&particle.speed, sizeof(speedSize));

        //speed variance
        float speedVarianceSize=0;
        file.read((char*)&speedVarianceSize,sizeof(float));
        file.read((char*)&particle.speedVariance, sizeof(speedVarianceSize));

        //life
        float lifeSpanSize=0;
        file.read((char*)&lifeSpanSize,sizeof(float));
        file.read((char*)&particle.lifeSpan, sizeof(lifeSpanSize));

        //maximum number of particles
        int maximumParticlesSize=0;
        file.read((char*)&maximumParticlesSize,sizeof(int));
        file.read((char*)&particle.maxParticles, sizeof(maximumParticlesSize));

        //angle
        float angleSize=0;
        file.read((char*)&angleSize,sizeof(float));
        file.read((char*)&particle.angle, sizeof(angleSize));

        //angle variance
        float angleVarianceSize=0;
        file.read((char*)&angleVarianceSize,sizeof(float));
        file.read((char*)&particle.angleVariance, sizeof(angleVarianceSize));

        //start color
        int startColorSize=0;
        file.read((char*)&startColorSize,sizeof(int));
        std::vector<float> tempStartColor(startColorSize,0);
        
        //copy temp to start color
        particle.startColor=tempStartColor;
        file.read((char*)&particle.startColor[0], startColorSize*sizeof(float));

        //start color variance
        int startColorVarianceSize=0;
        file.read((char*)&startColorVarianceSize,sizeof(int));
        std::vector<float> tempStartColorVariance(startColorVarianceSize,0);
        
        //copy temp to start color
        particle.startColorVariance=tempStartColorVariance;
        file.read((char*)&particle.startColorVariance[0], startColorVarianceSize*sizeof(float));

        //end color
        int endColorSize=0;
        file.read((char*)&endColorSize,sizeof(int));
        std::vector<float> tempEndColor(endColorSize,0);
        
        //copy temp to start color
        particle.finishColor=tempEndColor;
        file.read((char*)&particle.finishColor[0], endColorSize*sizeof(float));

        //end color variance
        int endColorVarianceSize=0;
        file.read((char*)&endColorVarianceSize,sizeof(int));
        std::vector<float> tempEndColorVariance(endColorVarianceSize,0);
        
        //copy temp to start color
        particle.finishColorVariance=tempEndColorVariance;
        file.read((char*)&particle.finishColorVariance[0], endColorVarianceSize*sizeof(float));

        //gravity
        int gravitySize=0;
        file.read((char*)&gravitySize,sizeof(int));
        std::vector<float> tempGravity(gravitySize,0);
        
        //copy temp to gravity
        particle.gravity=tempGravity;
        file.read((char*)&particle.gravity[0], gravitySize*sizeof(float));

        //start particle size
        float startParticleSize=0;
        file.read((char*)&startParticleSize,sizeof(float));
        file.read((char*)&particle.startParticleSize, sizeof(startParticleSize));

        //start particle size variance
        float startParticleVarianceSize=0;
        file.read((char*)&startParticleVarianceSize,sizeof(float));
        file.read((char*)&particle.startParticleSizeVariance, sizeof(startParticleVarianceSize));

        //end particle size
        float finishParticleSize=0;
        file.read((char*)&finishParticleSize,sizeof(float));
        file.read((char*)&particle.finishParticleSize, sizeof(finishParticleSize));

        //end particle size variance
        float finishParticleVarianceSize=0;
        file.read((char*)&finishParticleVarianceSize,sizeof(float));
        file.read((char*)&particle.finishParticleSizeVariance, sizeof(finishParticleVarianceSize));

        //duration
        float durationSize=0;
        file.read((char*)&durationSize,sizeof(float));
        file.read((char*)&particle.duration, sizeof(durationSize));

        //radial acceleration
        float radialAccelerationSize=0;
        file.read((char*)&radialAccelerationSize,sizeof(float));
        file.read((char*)&particle.radialAcceleration, sizeof(radialAccelerationSize));

        //radial acceleration variance
        float radialAccelerationVarianceSize=0;
        file.read((char*)&radialAccelerationVarianceSize,sizeof(float));
        file.read((char*)&particle.radialAccelerationVariance, sizeof(radialAccelerationVarianceSize));

        //tangent acceleration
        float tangentialAccelerationSize=0;
        file.read((char*)&tangentialAccelerationSize,sizeof(float));
        file.read((char*)&particle.tangentialAcceleration, sizeof(tangentialAccelerationSize));

        //tangent acceleration variance
        float tangentialAccelerationVarianceSize=0;
        file.read((char*)&tangentialAccelerationVarianceSize,sizeof(float));
        file.read((char*)&particle.tangentialAccelerationVariance, sizeof(tangentialAccelerationVarianceSize));

        //rotation start
        float rotationStartSize=0;
        file.read((char*)&rotationStartSize,sizeof(float));
        file.read((char*)&particle.rotationStart, sizeof(rotationStartSize));

        //rotation start variance
        float rotationStartVarianceSize=0;
        file.read((char*)&rotationStartVarianceSize,sizeof(float));
        file.read((char*)&particle.rotationStartVariance, sizeof(rotationStartVarianceSize));

        //rotation end
        float rotationEndSize=0;
        file.read((char*)&rotationEndSize,sizeof(float));
        file.read((char*)&particle.rotationEnd, sizeof(rotationEndSize));

        //rotation end variance
        float rotationEndVarianceSize=0;
        file.read((char*)&rotationEndVarianceSize,sizeof(float));
        file.read((char*)&particle.rotationEndVariance, sizeof(rotationEndVarianceSize));

        //blending source
        float blendingSourceSize=0;
        file.read((char*)&blendingSourceSize,sizeof(float));
        file.read((char*)&particle.blendFunctionSource, sizeof(blendingSourceSize));

        //blending dest
        float blendingDestinationSize=0;
        file.read((char*)&blendingDestinationSize,sizeof(float));
        file.read((char*)&particle.blendFunctionDestination, sizeof(blendingDestinationSize));

        //texture
        size_t textureNamelen=0;
        file.read((char*)&textureNamelen,sizeof(textureNamelen));
        particle.texture.resize(textureNamelen);
        file.read((char*)&particle.texture[0],textureNamelen);
        
        //load particle into container
        particlesContainer.push_back(particle);
        
        return true;
        
    }


    bool U4DResourceLoader::loadFontData(std::string uFilepath){
        
        std::ifstream file(uFilepath, std::ios::in | std::ios::binary );
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(!file){
            
            logger->log("Error: Couldn't load the Font Asset File, No file %s exist.",uFilepath.c_str());
            
            return false;
            
        }
        
        file.seekg(0);
        
        FONTDATARAW fonts;
        
        //READ NAME
        size_t fontNamelen=0;
        file.read((char*)&fontNamelen,sizeof(fontNamelen));
        fonts.name.resize(fontNamelen);
        file.read((char*)&fonts.name[0],fontNamelen);
        
        //font size
        int fontSize=0;
        file.read((char*)&fontSize,sizeof(int));
        file.read((char*)&fonts.fontSize, sizeof(fontSize));
        
        //Font ATLAS Width
        float atlasWidthSize=0;
        file.read((char*)&atlasWidthSize,sizeof(float));
        file.read((char*)&fonts.fontAtlasWidth, sizeof(atlasWidthSize));
        
        //Font ATLAS Height
        float atlasHeightSize=0;
        file.read((char*)&atlasHeightSize,sizeof(float));
        file.read((char*)&fonts.fontAtlasHeight, sizeof(atlasHeightSize));
        
        //texture
        //get the size of the string
         size_t fontTexturelen=0;
         file.read((char*)&fontTexturelen,sizeof(fontTexturelen));
         fonts.texture.resize(fontTexturelen);
         file.read((char*)&fonts.texture[0],fontTexturelen);
        
        //WRITE NUMBER OF Characters
        int charCountSize=0;
        file.read((char*)&charCountSize,sizeof(int));
        file.read((char*)&fonts.charCount, sizeof(charCountSize));
        
        for (int i=0; i<charCountSize; i++) {
            
            CHARACTERDATARAW characterData;
            
            //id int
            int idSize=0;
            file.read((char*)&idSize,sizeof(int));
            file.read((char*)&characterData.ID, sizeof(idSize));
            
            //x-position float
            float xPositionSize=0;
            file.read((char*)&xPositionSize,sizeof(float));
            file.read((char*)&characterData.x, sizeof(xPositionSize));
            
            //y-position
            float yPositionSize=0;
            file.read((char*)&yPositionSize,sizeof(float));
            file.read((char*)&characterData.y, sizeof(yPositionSize));

            //width
            float widthSize=0;
            file.read((char*)&widthSize,sizeof(float));
            file.read((char*)&characterData.width, sizeof(widthSize));

            //height
            float heightSize=0;
            file.read((char*)&heightSize,sizeof(float));
            file.read((char*)&characterData.height, sizeof(heightSize));

            //x-offset
            float xOffsetSize=0;
            file.read((char*)&xOffsetSize,sizeof(float));
            file.read((char*)&characterData.xoffset, sizeof(xOffsetSize));

            //y-offset
            float yOffsetSize=0;
            file.read((char*)&yOffsetSize,sizeof(float));
            file.read((char*)&characterData.yoffset, sizeof(yOffsetSize));

            //x advance
            float xAdvanceSize=0;
            file.read((char*)&xAdvanceSize,sizeof(float));
            file.read((char*)&characterData.xadvance, sizeof(xAdvanceSize));
            
            size_t letterlen=0;
            file.read((char*)&letterlen,sizeof(letterlen));
            characterData.letter.resize(letterlen);
            file.read((char*)&characterData.letter[0],letterlen);
            
            fonts.characterData.push_back(characterData);
            
        }
        
        //load data into font container
        fontsContainer.push_back(fonts);
        
        logger->log("Success: Font Asset File %s succesfully Loaded.",uFilepath.c_str());
        
        return true;
        
    }

    bool U4DResourceLoader::loadLightData(std::string uFilepath){
        
        U4DPointLight *pointLights=U4DPointLight::sharedInstance();
        
        std::ifstream file(uFilepath, std::ios::in | std::ios::binary );
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(!file){
            
            logger->log("Error: Couldn't load the Font Asset File, No file %s exist.",uFilepath.c_str());
            
            return false;
            
        }
        
        file.seekg(0);
        
        LIGHTDATARAW lights;
        
        //Number of directional lights
        int numberOfDirLightSize=0;
        file.read((char*)&numberOfDirLightSize,sizeof(int));
        file.read((char*)&lights.numberOfDirectionalLights, sizeof(numberOfDirLightSize));
        
        for (int i=0; i<numberOfDirLightSize; i++) {
            
            DIRECTIONALLIGHTRAW dirLight;
            
            //READ NAME
            size_t lightNamelen=0;
            file.read((char*)&lightNamelen,sizeof(lightNamelen));
            dirLight.name.resize(lightNamelen);
            file.read((char*)&dirLight.name[0],lightNamelen);
            
            //Energy
            float energySize=0;
            file.read((char*)&energySize,sizeof(float));
            file.read((char*)&dirLight.energy, sizeof(energySize));
            
            //color
            int colorSize=0;
            file.read((char*)&colorSize,sizeof(int));
            std::vector<float> tempColor(colorSize,0);
            
            //copy temp to color
            dirLight.color=tempColor;
            file.read((char*)&dirLight.color[0], colorSize*sizeof(float));
            
            //READ LOCAL MATRIX
            int localMatrixSize=0;
            file.read((char*)&localMatrixSize,sizeof(int));
            std::vector<float> tempLocalMatrix(localMatrixSize,0);
            
            //copy temp to light matrix
            dirLight.localMatrix=tempLocalMatrix;
            file.read((char*)&dirLight.localMatrix[0], localMatrixSize*sizeof(float));
            
            lights.directionalLights.push_back(dirLight);
            
        }
        
        //Number of point lights
        int numberOfPointLightSize=0;
        file.read((char*)&numberOfPointLightSize,sizeof(int));
        file.read((char*)&lights.numberOfPointLights, sizeof(numberOfPointLightSize));
        
        for (int i=0; i<numberOfPointLightSize; i++) {
            
            POINTLIGHTRAW pointLight;
            
            //READ NAME
            size_t lightNamelen=0;
            file.read((char*)&lightNamelen,sizeof(lightNamelen));
            pointLight.name.resize(lightNamelen);
            file.read((char*)&pointLight.name[0],lightNamelen);
            
            //Energy
            float energySize=0;
            file.read((char*)&energySize,sizeof(float));
            file.read((char*)&pointLight.energy, sizeof(energySize));
            
            //Fallout distance
            float falloutSize=0;
            file.read((char*)&falloutSize,sizeof(float));
            file.read((char*)&pointLight.falloutDistance, sizeof(falloutSize));
            
            //constant coefficient
            float constantCoefficientSize=0;
            file.read((char*)&constantCoefficientSize,sizeof(float));
            file.read((char*)&pointLight.constantCoefficient, sizeof(constantCoefficientSize));
            
            //linear coefficient
            float linearCoefficientSize=0;
            file.read((char*)&linearCoefficientSize,sizeof(float));
            file.read((char*)&pointLight.linearCoefficient, sizeof(linearCoefficientSize));
            
            //quadratic coefficient
            float quadraticCoefficientSize=0;
            file.read((char*)&quadraticCoefficientSize,sizeof(float));
            file.read((char*)&pointLight.quadraticCoefficient, sizeof(quadraticCoefficientSize));
            //color
            int colorSize=0;
            file.read((char*)&colorSize,sizeof(int));
            std::vector<float> tempColor(colorSize,0);
            
            //copy temp to color
            pointLight.color=tempColor;
            file.read((char*)&pointLight.color[0], colorSize*sizeof(float));
            
            //READ LOCAL MATRIX
            int localMatrixSize=0;
            file.read((char*)&localMatrixSize,sizeof(int));
            std::vector<float> tempLocalMatrix(localMatrixSize,0);
            
            //copy temp to light matrix
            pointLight.localMatrix=tempLocalMatrix;
            file.read((char*)&pointLight.localMatrix[0], localMatrixSize*sizeof(float));
            
            U4DVector3n position(pointLight.localMatrix[3],pointLight.localMatrix[7],pointLight.localMatrix[11]);
            U4DVector3n color(pointLight.color[0],pointLight.color[1],pointLight.color[2]);
            
            pointLights->addLight(position, color, pointLight.constantCoefficient,pointLight.linearCoefficient, pointLight.quadraticCoefficient,pointLight.energy, pointLight.falloutDistance);
            
        }
        
        logger->log("Success: Light Asset File %s succesfully Loaded.",uFilepath.c_str());
        
        return true;
        
    }

    bool U4DResourceLoader::loadAssetToMesh(U4DModel *uModel,std::string uMeshName){

        //find the model in the container
        U4DLogger *logger=U4DLogger::sharedInstance();
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        U4DWorld *world=scene->getGameWorld();
        
        for(int n=0;n<modelsContainer.size();n++){

            if (modelsContainer.at(n).name.compare(uMeshName)==0) {
                
                //copy the data
                uModel->setName(modelsContainer.at(n).name);
                
                
                //VERTICES
                loadVerticesData(uModel, modelsContainer.at(n).vertices);
                
                //NORMALS
                loadNormalData(uModel, modelsContainer.at(n).normals);
                
                //UVs
                loadUVData(uModel, modelsContainer.at(n).uv);
                
                //INDEX
                loadIndexData(uModel, modelsContainer.at(n).index);
                
                //MATERIAL INDEX
                loadMaterialIndexData(uModel, modelsContainer.at(n).materialIndex);
                
                //DIFFUSE COLOR
                loadDiffuseColorData(uModel, modelsContainer.at(n).diffuseColor);
                
                //SPECULAR COLOR
                loadSpecularColorsData(uModel, modelsContainer.at(n).specularColor);
                
                //DIFFUSE INTENSITY
                loadDiffuseIntensityData(uModel, modelsContainer.at(n).diffuseIntensity);
                
                //SPECULAR INTENSITY
                loadSpecularIntensityData(uModel, modelsContainer.at(n).specularIntensity);
                
                //SPECULAR HARDNESS
                loadSpecularHardnessData(uModel, modelsContainer.at(n).specularHardness);
                
                //TEXTURE IMAGE
                uModel->setTexture0(modelsContainer.at(n).textureImage);
                
                //LOCAL MATRIX
                loadEntityMatrixSpace(uModel, modelsContainer.at(n).localMatrix);
                
                //DIMENSION
                loadDimensionDataToBody(uModel, modelsContainer.at(n).dimension);
                
                //MESH VERTICES
                loadMeshVerticesData(uModel, modelsContainer.at(n).meshVertices);
                
                //MESH EDGES INDEX
                loadMeshEdgesData(uModel, modelsContainer.at(n).meshEdgesIndex);
                
                //MESH FACES INDEX
                loadMeshFacesData(uModel, modelsContainer.at(n).meshFacesIndex);
                
                //LOAD ARMATURE
                if(modelsContainer.at(n).armature.bones.size()>0){
                    
                    uModel->setHasArmature(true);
                    
                    //read the Bind Shape Matrix
                    loadSpaceData(uModel->armatureManager->bindShapeSpace, modelsContainer.at(n).armature.bindShapeMatrix);
                    
                    //root bone
                    U4DBoneData *rootBone=NULL;
                    
                    //iterate through all the bones in the armature
                    for(auto b:modelsContainer.at(n).armature.bones){
                        
                        if (b.parent.compare("root")==0) {
                            
                            //if bone is root, then create a bone with parent set to root
                            rootBone=new U4DBoneData();
                            
                            rootBone->name=b.name;
                            
                            //add the local matrix
                            loadSpaceData(rootBone->localSpace, b.localMatrix);
                            
                            //add the bind pose Matrix
                            loadSpaceData(rootBone->bindPoseSpace, b.bindPoseMatrix);
                            
                            //add the bind pose inverse matrix
                            loadSpaceData(rootBone->inverseBindPoseSpace, b.inversePoseMatrix);
                            
                            //add the vertex weights
                            loadVertexBoneWeightsToBody(rootBone->vertexWeightContainer, b.vertexWeights);
                            
                            //add the bone to the U4DModel
                            uModel->armatureManager->setRootBone(rootBone);
                            
                        }else{ //bone is either a parent,child but not root
                            
                            //1.look for the bone parent
                            
                            U4DBoneData *boneParent=rootBone->searchChild(b.parent);
                            
                            //create the new bone
                            U4DBoneData *childBone=new U4DBoneData();
                            
                            //set name
                            childBone->name=b.name;
                            
                            //add the local matrix
                            loadSpaceData(childBone->localSpace, b.localMatrix);
                            
                            //add the bind pose Matrix
                            loadSpaceData(childBone->bindPoseSpace, b.bindPoseMatrix);
                            
                            //add the bind pose inverse matrix
                            loadSpaceData(childBone->inverseBindPoseSpace, b.inversePoseMatrix);
                            
                            //add the vertex weights
                            loadVertexBoneWeightsToBody(childBone->vertexWeightContainer, b.vertexWeights);
                            
                            //add the bone to the parent
                            uModel->armatureManager->addBoneToTree(boneParent, childBone);
                            
                        }//end else
                        
                    }//end for
                    
                    //arrange all bone's local space (in PRE-ORDER TRAVERSAL) and load them into the
                    //boneDataContainer
                    uModel->armatureManager->setBoneDataContainer();
                    
                    //set bone's absolute space
                    uModel->armatureManager->setBoneAbsoluteSpace();
                    
                    //Load the bone data into the uModel FinalArmatureBoneMatrix
                    uModel->armatureManager->setRestPoseMatrix();
                    
                    //arrange (in PRE-ORDER TRAVERSAL) all vertex weights, then do a heap sort for the four
                    //bones that affect each vertex depending on the vertex weight
                    uModel->armatureManager->setVertexWeightsAndBoneIndices();
                    
                }

                logger->log("Success: The model %s  was loaded.",uMeshName.c_str());
                
                return true;
            }
            
        }
        
        logger->log("Error: The model %s does not exist.",uMeshName.c_str());
        
        return false;
        
    }


    bool U4DResourceLoader::loadAnimationToMesh(U4DAnimation *uAnimation,std::string uAnimationName){
        
        int keyframeRange=0;
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        for(int n=0;n<animationsContainer.size();n++){
            
            if (animationsContainer.at(n).name.compare(uAnimationName)==0){
                
                //ANIMATION TRANSFORM
                loadSpaceData(uAnimation->modelerAnimationTransform, animationsContainer.at(n).poseTransform);
                
                U4DBoneData* boneChild = uAnimation->rootBone;
                
                //While there are still bones
                while (boneChild!=0) {
                    
                    ANIMATIONDATA animationData;
                    
                    //ANIMATION NAME
                    animationData.name=animationsContainer.at(n).name;
                    uAnimation->name=animationsContainer.at(n).name;
                    
                    //FPS
                    uAnimation->fps=animationsContainer.at(n).fps;
                    
                    //KEYFRAME DATA
                    keyframeRange=0;
                    
                    for(int m=0;m<animationsContainer.at(n).keyframes.size();m++){
                        
                        KEYFRAMEDATA keyframeData;
                        KEYFRAMERAW keyframeRaw=animationsContainer.at(n).keyframes.at(m);
                        
                        //TIME
                        keyframeData.time=keyframeRaw.time;
                        
                        //set keyframe name--I DON'T THINK THIS IS NEEDED ANYMORE
                        std::string keyframeCountString=std::to_string(keyframeRange);
                        
                        std::string keyframeName="keyframe";
                        keyframeName.append(keyframeCountString);
                        
                        keyframeData.name=keyframeName;
                        
                        keyframeRange++;
                        
                        //BONE POSE SPACE
                        for(int p=0;p<keyframeRaw.animPoseMatrix.size();p++){
                            
                            //BONE NAME
                            //compare bone names
                            if (boneChild->name.compare(keyframeRaw.animPoseMatrix.at(p).boneName)==0) {
                                
                                //POSE MATRIX
                                U4DDualQuaternion animationMatrixSpace;
                                loadSpaceData(animationMatrixSpace, keyframeRaw.animPoseMatrix.at(p).poseMatrix);
                                
                                //load the bone pose transform
                                keyframeData.animationSpaceTransform=animationMatrixSpace;
                                
                            }
                            
                        }//END FOR LOOP
                        
                        //add keyframe into the animationdata container
                        animationData.keyframes.push_back(keyframeData);
                        
                    }//END FOR LOOP
                    
                    //Add the animation to the animation container
                    uAnimation->animationsContainer.push_back(animationData);
                        
                    //iterate to the next child
                    boneChild=boneChild->next;
                        
                }//end while
                
                //store the keyframe range
                uAnimation->keyframeRange=keyframeRange;
                
                logger->log("Success: The animation %s  was loaded.",uAnimationName.c_str());
                
                return true;
            }
            
        }
        
        logger->log("Error: The animation %s  was not found.",uAnimationName.c_str());
        
        return false;
    }

    CONVEXHULL U4DResourceLoader::loadConvexHullForMesh(U4DModel *uModel){
        
        CONVEXHULL convexHull;
        
        for(int n=0;n<convexHullContainer.size();n++){

            if (convexHullContainer.at(n).name.compare(uModel->getName())==0) {
         
                convexHull.isValid=false;
                
                std::vector<float> convexHullVerticesContainer=convexHullContainer.at(n).convexHullVertices;
                std::vector<float> convexHullEdgesContainer=convexHullContainer.at(n).convexHullEdges;
                std::vector<float> convexHullFacesContainer=convexHullContainer.at(n).convexHullFaces;
                
                //is it valide
                if (convexHullVerticesContainer.size()>0) {
                    convexHull.isValid=true;
                }
                
                //load vertices
                for(int v=0;v<convexHullVerticesContainer.size();){
                    
                    U4DVector3n computedVertex(convexHullVerticesContainer.at(v),convexHullVerticesContainer.at(v+1), convexHullVerticesContainer.at(v+2));
                    
                    POLYTOPEVERTEX polytopeVertex;
                    polytopeVertex.vertex=computedVertex;
                    
                    convexHull.vertex.push_back(polytopeVertex);
                    
                    v=v+3;
                    
                }
                
                //load edges
                for(int e=0;e<convexHullEdgesContainer.size();){
                    
                    
                    U4DPoint3n a(convexHullEdgesContainer.at(e),convexHullEdgesContainer.at(e+1),convexHullEdgesContainer.at(e+2));
                    U4DPoint3n b(convexHullEdgesContainer.at(e+3),convexHullEdgesContainer.at(e+4),convexHullEdgesContainer.at(e+5));
                    
                    U4DSegment segment(a,b);
                    
                    POLYTOPEEDGES polytopeEdge;
                    polytopeEdge.segment=segment;
                    
                    convexHull.edges.push_back(polytopeEdge);
                    
                    e=e+6;
                    
                }
                
                //load faces
                for(int f=0;f<convexHullFacesContainer.size();){
                    
                    U4DPoint3n a(convexHullFacesContainer.at(f),convexHullFacesContainer.at(f+1),convexHullFacesContainer.at(f+2));
                    U4DPoint3n b(convexHullFacesContainer.at(f+3),convexHullFacesContainer.at(f+4),convexHullFacesContainer.at(f+5));
                    U4DPoint3n c(convexHullFacesContainer.at(f+6),convexHullFacesContainer.at(f+7),convexHullFacesContainer.at(f+8));
                    
                    U4DTriangle triangle(a,b,c);
                    
                    POLYTOPEFACES polytopeFace;
                    polytopeFace.triangle=triangle;
                    
                    convexHull.faces.push_back(polytopeFace);
                    
                    f=f+9;
                    
                }
                
                
            }
            
            
        }
        
        return convexHull;
        
    }

    void U4DResourceLoader::loadVerticesData(U4DModel *uModel,std::vector<float> uVertices){
        
        for (int i=0; i<uVertices.size();) {
            
            float x=uVertices.at(i);
            
            float y=uVertices.at(i+1);
            
            float z=uVertices.at(i+2);
            
            U4DVector3n uVertices(x,y,z);
            
            uModel->bodyCoordinates.addVerticesDataToContainer(uVertices);
            i=i+3;
            
        }
        
    }

    void U4DResourceLoader::loadNormalData(U4DModel *uModel,std::vector<float> uNormals){

        
        for (int i=0; i<uNormals.size();) {
            
            float n1=uNormals.at(i);
            
            float n2=uNormals.at(i+1);
            
            float n3=uNormals.at(i+2);
            
            U4DVector3n Normal(n1,n2,n3);
            
            uModel->bodyCoordinates.addNormalDataToContainer(Normal);
            i=i+3;
            
        }
        
    }

    void U4DResourceLoader::loadUVData(U4DModel *uModel,std::vector<float> uUV){
        
        for (int i=0; i<uUV.size();) {
            
            float s=uUV.at(i);
            
            float t=uUV.at(i+1);
            
            U4DVector2n UV(s,t);
            
            uModel->bodyCoordinates.addUVDataToContainer(UV);
            i=i+2;
            
        }
        
    }

    void U4DResourceLoader::loadIndexData(U4DModel *uModel,std::vector<int> uIndex){
        
        for (int i=0; i<uIndex.size();) {
            
            int i1=uIndex.at(i);
            int i2=uIndex.at(i+1);
            int i3=uIndex.at(i+2);
            
            U4DIndex index(i1,i2,i3);
            
            uModel->bodyCoordinates.addIndexDataToContainer(index);
            
            i=i+3;
        }
        
    }

    void U4DResourceLoader::loadMaterialIndexData(U4DModel *uModel,std::vector<int> uMaterialIndex){
        
        for (int i=0; i<uMaterialIndex.size(); i++) {
            
            float materialIndex=uMaterialIndex.at(i);
            
            uModel->materialInformation.addMaterialIndexDataToContainer(materialIndex);
            
        }
    }
        
    void U4DResourceLoader::loadDiffuseColorData(U4DModel *uModel,std::vector<float> uDiffuseColor){
        
        for (int i=0; i<uDiffuseColor.size();) {
            
            float x=uDiffuseColor.at(i);
            
            float y=uDiffuseColor.at(i+1);
            
            float z=uDiffuseColor.at(i+2);
            
            float a=uDiffuseColor.at(i+3);
            
            U4DColorData uDiffuseColor(x,y,z,a);
            
            uModel->materialInformation.addDiffuseMaterialDataToContainer(uDiffuseColor);
            
            i=i+4;
            
        }
    }
        
    void U4DResourceLoader::loadSpecularColorsData(U4DModel *uModel,std::vector<float> uSpecularColor){
        
        for (int i=0; i<uSpecularColor.size();) {
            
            float x=uSpecularColor.at(i);
            
            float y=uSpecularColor.at(i+1);
            
            float z=uSpecularColor.at(i+2);
            
            float a=uSpecularColor.at(i+3);
            
            U4DColorData uSpecularColor(x,y,z,a);
            
            uModel->materialInformation.addSpecularMaterialDataToContainer(uSpecularColor);
            
            i=i+4;
            
        }
        
    }
        
    void U4DResourceLoader::loadDiffuseIntensityData(U4DModel *uModel,std::vector<float> uDiffuseIntensity){
        
        for (int i=0; i<uDiffuseIntensity.size();i++) {
            
            float diffuseIntensity=uDiffuseIntensity.at(i);
            uModel->materialInformation.addDiffuseIntensityMaterialDataToContainer(diffuseIntensity);
            
        }
        
    }
        
    void U4DResourceLoader::loadSpecularIntensityData(U4DModel *uModel,std::vector<float> uSpecularIntesity){
        
        for (int i=0; i<uSpecularIntesity.size();i++) {
            
            float specularIntensity=uSpecularIntesity.at(i);
            uModel->materialInformation.addSpecularIntensityMaterialDataToContainer(specularIntensity);
            
        }
        
    }
        
    void U4DResourceLoader::loadSpecularHardnessData(U4DModel *uModel,std::vector<float> uSpecularHardness){
        
        for (int i=0; i<uSpecularHardness.size();i++) {
            
            float specularHardness=uSpecularHardness.at(i);
            uModel->materialInformation.addSpecularHardnessMaterialDataToContainer(specularHardness);
            
        }
        
    }
        
    void U4DResourceLoader::loadDimensionDataToBody(U4DModel *uModel,std::vector<float> uDimension){
        
        float x=uDimension.at(0);
        
        float y=uDimension.at(2);
        
        float z=uDimension.at(1);
        
        U4DVector3n modelDimension(x,y,z);
        
        uModel->bodyCoordinates.setModelDimension(modelDimension);
        
    }
        
    void U4DResourceLoader::loadEntityMatrixSpace(U4DEntity *uModel,std::vector<float> uLocalMatrix){
        
        //    0    4    8    12
        //    1    5    9    13
        //    2    6    10    14
        //    3    7    11    15
        
        U4DMatrix4n tempMatrix;
        
        tempMatrix.matrixData[0]=uLocalMatrix.at(0);
        tempMatrix.matrixData[4]=uLocalMatrix.at(1);
        tempMatrix.matrixData[8]=uLocalMatrix.at(2);
        tempMatrix.matrixData[12]=uLocalMatrix.at(3);
        
        tempMatrix.matrixData[1]=uLocalMatrix.at(4);
        tempMatrix.matrixData[5]=uLocalMatrix.at(5);
        tempMatrix.matrixData[9]=uLocalMatrix.at(6);
        tempMatrix.matrixData[13]=uLocalMatrix.at(7);
        
        tempMatrix.matrixData[2]=uLocalMatrix.at(8);
        tempMatrix.matrixData[6]=uLocalMatrix.at(9);
        tempMatrix.matrixData[10]=uLocalMatrix.at(10);
        tempMatrix.matrixData[14]=uLocalMatrix.at(11);
        
        tempMatrix.matrixData[3]=uLocalMatrix.at(12);
        tempMatrix.matrixData[7]=uLocalMatrix.at(13);
        tempMatrix.matrixData[11]=uLocalMatrix.at(14);
        tempMatrix.matrixData[15]=uLocalMatrix.at(15);
        
        U4DDualQuaternion modelDualQuaternion;
        modelDualQuaternion.transformMatrix4nToDualQuaternion(tempMatrix);
        
        uModel->setLocalSpace(modelDualQuaternion);
        
    }

    void U4DResourceLoader::loadMeshVerticesData(U4DModel *uModel,std::vector<float> uMeshVertices){
        
        for (int i=0; i<uMeshVertices.size();) {
            
            float x=uMeshVertices.at(i);
            
            float y=uMeshVertices.at(i+1);
            
            float z=uMeshVertices.at(i+2);
            
            U4DVector3n uMeshVertices(x,y,z);
            
            uModel->polygonInformation.addVertexToContainer(uMeshVertices);
            i=i+3;
            
        }
        
    }
        
    void U4DResourceLoader::loadMeshEdgesData(U4DModel *uModel,std::vector<int> uMeshEdgesIndex){
        
        for (int i=0; i<uMeshEdgesIndex.size();) {
            
            int i1=uMeshEdgesIndex.at(i);
            int i2=uMeshEdgesIndex.at(i+1);
            
            U4DPoint3n point1=uModel->polygonInformation.verticesContainer.at(i1).toPoint();
            U4DPoint3n point2=uModel->polygonInformation.verticesContainer.at(i2).toPoint();
            
            U4DSegment edge(point1,point2);
            
            uModel->polygonInformation.addEdgeToContainer(edge);
            i=i+2;
            
        }
        
    }
        
    void U4DResourceLoader::loadMeshFacesData(U4DModel *uModel,std::vector<int> uMeshFacesIndex){

        for (int i=0; i<uMeshFacesIndex.size();) {
            
            int i1=uMeshFacesIndex.at(i);
            int i2=uMeshFacesIndex.at(i+1);
            int i3=uMeshFacesIndex.at(i+2);
            
            U4DPoint3n point1=uModel->polygonInformation.verticesContainer.at(i1).toPoint();
            U4DPoint3n point2=uModel->polygonInformation.verticesContainer.at(i2).toPoint();
            U4DPoint3n point3=uModel->polygonInformation.verticesContainer.at(i3).toPoint();
            
            //assemble the triangle ccw
            U4DTriangle face(point3,point2,point1);
            
            uModel->polygonInformation.addFaceToContainer(face);
            
            i=i+3;
            
        }
        
    }

    void U4DResourceLoader::loadSpaceData(U4DMatrix4n &uMatrix, std::vector<float> uSpaceData){
        
        //    0    4    8    12
        //    1    5    9    13
        //    2    6    10    14
        //    3    7    11    15
        
        
        uMatrix.matrixData[0]=uSpaceData.at(0);
        uMatrix.matrixData[4]=uSpaceData.at(1);
        uMatrix.matrixData[8]=uSpaceData.at(2);
        uMatrix.matrixData[12]=uSpaceData.at(3);
        
        uMatrix.matrixData[1]=uSpaceData.at(4);
        uMatrix.matrixData[5]=uSpaceData.at(5);
        uMatrix.matrixData[9]=uSpaceData.at(6);
        uMatrix.matrixData[13]=uSpaceData.at(7);
        
        uMatrix.matrixData[2]=uSpaceData.at(8);
        uMatrix.matrixData[6]=uSpaceData.at(9);
        uMatrix.matrixData[10]=uSpaceData.at(10);
        uMatrix.matrixData[14]=uSpaceData.at(11);
        
        uMatrix.matrixData[3]=uSpaceData.at(12);
        uMatrix.matrixData[7]=uSpaceData.at(13);
        uMatrix.matrixData[11]=uSpaceData.at(14);
        uMatrix.matrixData[15]=uSpaceData.at(15);
        
    }

    void U4DResourceLoader::loadSpaceData(U4DDualQuaternion &uSpace, std::vector<float> uSpaceData){
        
        //    0    4    8    12
        //    1    5    9    13
        //    2    6    10    14
        //    3    7    11    15
        
       
        U4DMatrix4n tempMatrix;
        
        tempMatrix.matrixData[0]=uSpaceData.at(0);
        tempMatrix.matrixData[4]=uSpaceData.at(1);
        tempMatrix.matrixData[8]=uSpaceData.at(2);
        tempMatrix.matrixData[12]=uSpaceData.at(3);
        
        tempMatrix.matrixData[1]=uSpaceData.at(4);
        tempMatrix.matrixData[5]=uSpaceData.at(5);
        tempMatrix.matrixData[9]=uSpaceData.at(6);
        tempMatrix.matrixData[13]=uSpaceData.at(7);
        
        tempMatrix.matrixData[2]=uSpaceData.at(8);
        tempMatrix.matrixData[6]=uSpaceData.at(9);
        tempMatrix.matrixData[10]=uSpaceData.at(10);
        tempMatrix.matrixData[14]=uSpaceData.at(11);
        
        tempMatrix.matrixData[3]=uSpaceData.at(12);
        tempMatrix.matrixData[7]=uSpaceData.at(13);
        tempMatrix.matrixData[11]=uSpaceData.at(14);
        tempMatrix.matrixData[15]=uSpaceData.at(15);
        
        
        uSpace.transformMatrix4nToDualQuaternion(tempMatrix);
        
    }

    void U4DResourceLoader::loadVertexBoneWeightsToBody(std::vector<float> &uVertexWeights,std::vector<float> uWeights){
        
        
        for (int i=0; i<uWeights.size();i++) {
         
            uVertexWeights.push_back(uWeights.at(i));
        }
        
    }

    bool U4DResourceLoader::loadParticeToParticleSystem(U4DParticleSystem *uParticleSystem, std::string uParticleName){
     
        //find the model in the container
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        for(const auto &n:particlesContainer){

            if (n.name.compare(uParticleName)==0) {
                
                //copy the data
                
                //position variance
                uParticleSystem->particleSystemData.particlePositionVariance=U4DVector3n(n.positionVariance.at(0),n.positionVariance.at(1),n.positionVariance.at(2));
                
                //speed
                uParticleSystem->particleSystemData.particleSpeed=n.speed;

                //speed variance
                uParticleSystem->particleSystemData.particleSpeedVariance=n.speedVariance;

                //life
                uParticleSystem->particleSystemData.particleLife=n.lifeSpan;

                //maximum number of particles
                uParticleSystem->particleSystemData.maxNumberOfParticles=n.maxParticles;

                //angle
                uParticleSystem->particleSystemData.particleEmitAngle=n.angle;

                //angle variance
                uParticleSystem->particleSystemData.particleEmitAngleVariance=n.angleVariance;

                //start color
                uParticleSystem->particleSystemData.particleStartColor=U4DVector4n(n.startColor.at(0),n.startColor.at(1),n.startColor.at(2),n.startColor.at(3));

                //start color variance
                uParticleSystem->particleSystemData.particleStartColorVariance=U4DVector4n(n.startColorVariance.at(0),n.startColorVariance.at(1),n.startColorVariance.at(2),n.startColorVariance.at(3));

                //end color
                uParticleSystem->particleSystemData.particleEndColor=U4DVector4n(n.finishColor.at(0),n.finishColor.at(1),n.finishColor.at(2),n.finishColor.at(3));

                //end color variance
                uParticleSystem->particleSystemData.particleEndColorVariance=U4DVector4n(n.finishColorVariance.at(0),n.finishColorVariance.at(1),n.finishColorVariance.at(2),n.finishColorVariance.at(3));

                //gravity
                uParticleSystem->particleSystemData.gravity=U4DVector3n(n.gravity.at(0),n.gravity.at(1),n.gravity.at(2));
                
                //start particle size
                uParticleSystem->particleSystemData.startParticleSize=n.startParticleSize;

                //start particle size variance
                uParticleSystem->particleSystemData.startParticleSizeVariance=n.startParticleSizeVariance;

                //end particle size
                uParticleSystem->particleSystemData.endParticleSize=n.finishParticleSize;

                //end particle size variance
                uParticleSystem->particleSystemData.endParticleSizeVariance=n.finishParticleSizeVariance;

                //duration
                uParticleSystem->particleSystemData.emitterDurationRate=n.duration;

                //radial acceleration
                uParticleSystem->particleSystemData.particleRadialAcceleration=n.radialAcceleration;

                //radial acceleration variance
                uParticleSystem->particleSystemData.particleRadialAccelerationVariance=n.radialAccelerationVariance;

                //tangent acceleration
                uParticleSystem->particleSystemData.particleTangentialAcceleration=n.tangentialAcceleration;

                //tangent acceleration variance
                uParticleSystem->particleSystemData.particleRadialAccelerationVariance=n.tangentialAccelerationVariance;

                //rotation start
                uParticleSystem->particleSystemData.startParticleRotation=n.rotationStart;

                //rotation start variance
                uParticleSystem->particleSystemData.startParticleRotationVariance=n.rotationStartVariance;

                //rotation end
                uParticleSystem->particleSystemData.endParticleRotation=n.rotationEnd;

                //rotation end variance
                uParticleSystem->particleSystemData.endParticleRotationVariance=n.rotationEndVariance;

                //blending source
                uParticleSystem->particleSystemData.blendingFactorSource=n.blendFunctionSource;

                //blending dest
                uParticleSystem->particleSystemData.blendingFactorDest=n.blendFunctionDestination;

                //texture
                uParticleSystem->textureInformation.setTexture0(n.texture);
                
                for(int t=0;t<texturesContainer.size();t++){

                    if (texturesContainer.at(t).name.compare(n.texture)==0) {
                        
                        uParticleSystem->renderEntity->setRawImageData(texturesContainer.at(t).image);
                        uParticleSystem->renderEntity->setImageWidth(texturesContainer.at(t).width);
                        uParticleSystem->renderEntity->setImageHeight(texturesContainer.at(t).height);

                    }

                }
                    
                //defaults
                uParticleSystem->particleSystemData.particleSystemType=LINEAREMITTER;
                uParticleSystem->particleSystemData.numberOfParticlesPerEmission=1;
                uParticleSystem->particleSystemData.emissionRate=U4DEngine::particleEmissionRate;
                uParticleSystem->particleSystemData.emitContinuously=true;
                
                
                logger->log("Success: The particle %s  was loaded.",uParticleName.c_str());
                
                return true;
                
            }
            
        }
        
        logger->log("Error: The particle %s does not exist.",uParticleName.c_str());
        
        return false;
        
        
    }


    bool U4DResourceLoader::loadFontToText(U4DText *uText, std::string uFontName){
        
        //find the model in the container
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        for(const auto &n:fontsContainer){

            if (n.name.compare(uFontName)==0) {
                
                //name
                uText->fontData.name=n.name;
                
                //font size
                uText->fontData.fontSize=n.fontSize;
                
                //font width
                uText->fontData.fontAtlasWidth=n.fontAtlasWidth;
                
                //height
                uText->fontData.fontAtlasHeight=n.fontAtlasHeight;
                
                //texture
                //uText->fontData.texture=n.texture;
                
                uText->textureInformation.setTexture0(n.texture);
                
                for(int t=0;t<texturesContainer.size();t++){

                    if (texturesContainer.at(t).name.compare(n.texture)==0) {
                        
                        uText->renderEntity->setRawImageData(texturesContainer.at(t).image);
                        uText->renderEntity->setImageWidth(texturesContainer.at(t).width);
                        uText->renderEntity->setImageHeight(texturesContainer.at(t).height);

                    }

                }
                
                //character count
                uText->fontData.charCount=n.charCount;
                
                for(int i=0;i<n.charCount;i++){
                
                    CHARACTERDATA characterData;
                    
                    //ID
                    characterData.ID=n.characterData.at(i).ID;
                    
                    //x-pos
                    characterData.x=n.characterData.at(i).x;
                    
                    //y-pos
                    characterData.y=n.characterData.at(i).y;
                    
                    //width
                    characterData.width=n.characterData.at(i).width;
                    
                    //height
                    characterData.height=n.characterData.at(i).height;
                    
                    //x-offset
                    characterData.xoffset=n.characterData.at(i).xoffset;
                    
                    //y-offset
                    characterData.yoffset=n.characterData.at(i).yoffset;
                    
                    //x-advance
                    characterData.xadvance=n.characterData.at(i).xadvance;
                    
                    //letter
                    characterData.letter=n.characterData.at(i).letter.c_str();
                    
                    uText->fontData.characterData.push_back(characterData);
                    
                }
                
                return true;
            }
        }
        
        logger->log("Error: The font %s does not exist.",uFontName.c_str());
        
        return false;
        
    }

    void U4DResourceLoader::loadNormalMap(U4DModel *uModel,std::string uNormalMapName){
        
        for(int t=0;t<texturesContainer.size();t++){

            if (texturesContainer.at(t).name.compare(uNormalMapName)==0) {
                
                uModel->renderEntity->setRawImageData(texturesContainer.at(t).image);
                uModel->renderEntity->setImageWidth(texturesContainer.at(t).width);
                uModel->renderEntity->setImageHeight(texturesContainer.at(t).height);

            }

        }
        
    }

    bool U4DResourceLoader::loadTextureDataToEntity(U4DRenderEntity *uRenderEntity, const char* uTextureName){
        
        for(int t=0;t<texturesContainer.size();t++){

            if (texturesContainer.at(t).name.compare(std::string(uTextureName))==0) {
                
                uRenderEntity->setRawImageData(texturesContainer.at(t).image);
                
                uRenderEntity->setImageWidth(texturesContainer.at(t).width);
                
                uRenderEntity->setImageHeight(texturesContainer.at(t).height);
                
                return true;
            }

        }
        
        return false;
        
    }

    void U4DResourceLoader::clear(){
        
        //clear all containers
        modelsContainer.clear();
        animationsContainer.clear();
        texturesContainer.clear();
        particlesContainer.clear();
        convexHullContainer.clear();
        
    }

    std::vector<MODELRAW> U4DResourceLoader::getModelContainer(){
        
        return modelsContainer;
        
    }

}
