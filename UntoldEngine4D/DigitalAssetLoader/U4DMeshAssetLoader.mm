//
//  U4DMeshAssetLoader.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DMeshAssetLoader.h"
#include "CommonProtocols.h"
#include "U4DModel.h"
#include "U4DMatrix4n.h"
#include "U4DVector4n.h"
#include "U4DSegment.h"
#include "U4DArmatureData.h"
#include "U4DBoneData.h"
#include "U4DAnimation.h"
#include "U4DLights.h"
#include "U4DLogger.h"
#include "U4DDirector.h"
#include "U4DLogger.h"

namespace U4DEngine {

    U4DMeshAssetLoader::U4DMeshAssetLoader(){
        
    }

    U4DMeshAssetLoader::~U4DMeshAssetLoader(){
        
    }

    U4DMeshAssetLoader* U4DMeshAssetLoader::instance=0;

    U4DMeshAssetLoader* U4DMeshAssetLoader::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMeshAssetLoader();
        }
        
        return instance;
    }

    bool U4DMeshAssetLoader::loadSceneData(std::string uFilepath){
        
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


    bool U4DMeshAssetLoader::loadAnimationData(std::string uFilepath){
        
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

    bool U4DMeshAssetLoader::loadTextureData(std::string uFilepath){
        
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

    bool U4DMeshAssetLoader::loadAssetToMesh(U4DModel *uModel,std::string uMeshName){

        //find the model in the container
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        for(int n=0;n<modelsContainer.size();n++){

            if (modelsContainer.at(n).name.compare(uMeshName)==0) {
                
                //copy the data
                
                //NAME
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
                if (modelsContainer.at(n).textureNameSize>0) {
                    
                    uModel->textureInformation.setDiffuseTexture(modelsContainer.at(n).textureImage);
                    
                    for(int t=0;t<texturesContainer.size();t++){

                        if (texturesContainer.at(t).name.compare(modelsContainer.at(n).textureImage)==0) {

                            uModel->renderManager->setRawImageData(texturesContainer.at(t).image);
                            uModel->renderManager->setImageWidth(texturesContainer.at(t).width);
                            uModel->renderManager->setImageHeight(texturesContainer.at(t).height);

                        }

                    }
                    
                
                }
                
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
                            
                            U4DBoneData *boneParent=rootBone->searchChildrenBone(b.parent);
                            
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
        
        logger->log("Success: The model %s does not exist.",uMeshName.c_str());
        
        return false;
        
    }


    bool U4DMeshAssetLoader::loadAnimationToMesh(U4DAnimation *uAnimation,std::string uAnimationName){
        
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

    CONVEXHULL U4DMeshAssetLoader::loadConvexHullForMesh(U4DModel *uModel){
        
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

    void U4DMeshAssetLoader::loadVerticesData(U4DModel *uModel,std::vector<float> uVertices){
        
        for (int i=0; i<uVertices.size();) {
            
            float x=uVertices.at(i);
            
            float y=uVertices.at(i+1);
            
            float z=uVertices.at(i+2);
            
            U4DVector3n uVertices(x,y,z);
            
            uModel->bodyCoordinates.addVerticesDataToContainer(uVertices);
            i=i+3;
            
        }
        
    }

    void U4DMeshAssetLoader::loadNormalData(U4DModel *uModel,std::vector<float> uNormals){

        
        for (int i=0; i<uNormals.size();) {
            
            float n1=uNormals.at(i);
            
            float n2=uNormals.at(i+1);
            
            float n3=uNormals.at(i+2);
            
            U4DVector3n Normal(n1,n2,n3);
            
            uModel->bodyCoordinates.addNormalDataToContainer(Normal);
            i=i+3;
            
        }
        
    }

    void U4DMeshAssetLoader::loadUVData(U4DModel *uModel,std::vector<float> uUV){
        
        for (int i=0; i<uUV.size();) {
            
            float s=uUV.at(i);
            
            float t=uUV.at(i+1);
            
            U4DVector2n UV(s,t);
            
            uModel->bodyCoordinates.addUVDataToContainer(UV);
            i=i+2;
            
        }
        
    }

    void U4DMeshAssetLoader::loadIndexData(U4DModel *uModel,std::vector<int> uIndex){
        
        for (int i=0; i<uIndex.size();) {
            
            int i1=uIndex.at(i);
            int i2=uIndex.at(i+1);
            int i3=uIndex.at(i+2);
            
            U4DIndex index(i1,i2,i3);
            
            uModel->bodyCoordinates.addIndexDataToContainer(index);
            
            i=i+3;
        }
        
    }

    void U4DMeshAssetLoader::loadMaterialIndexData(U4DModel *uModel,std::vector<int> uMaterialIndex){
        
        for (int i=0; i<uMaterialIndex.size(); i++) {
            
            float materialIndex=uMaterialIndex.at(i);
            
            uModel->materialInformation.addMaterialIndexDataToContainer(materialIndex);
            
        }
    }
        
    void U4DMeshAssetLoader::loadDiffuseColorData(U4DModel *uModel,std::vector<float> uDiffuseColor){
        
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
        
    void U4DMeshAssetLoader::loadSpecularColorsData(U4DModel *uModel,std::vector<float> uSpecularColor){
        
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
        
    void U4DMeshAssetLoader::loadDiffuseIntensityData(U4DModel *uModel,std::vector<float> uDiffuseIntensity){
        
        for (int i=0; i<uDiffuseIntensity.size();i++) {
            
            float diffuseIntensity=uDiffuseIntensity.at(i);
            uModel->materialInformation.addDiffuseIntensityMaterialDataToContainer(diffuseIntensity);
            
        }
        
    }
        
    void U4DMeshAssetLoader::loadSpecularIntensityData(U4DModel *uModel,std::vector<float> uSpecularIntesity){
        
        for (int i=0; i<uSpecularIntesity.size();i++) {
            
            float specularIntensity=uSpecularIntesity.at(i);
            uModel->materialInformation.addSpecularIntensityMaterialDataToContainer(specularIntensity);
            
        }
        
    }
        
    void U4DMeshAssetLoader::loadSpecularHardnessData(U4DModel *uModel,std::vector<float> uSpecularHardness){
        
        for (int i=0; i<uSpecularHardness.size();i++) {
            
            float specularHardness=uSpecularHardness.at(i);
            uModel->materialInformation.addSpecularHardnessMaterialDataToContainer(specularHardness);
            
        }
        
    }
        
    void U4DMeshAssetLoader::loadDimensionDataToBody(U4DModel *uModel,std::vector<float> uDimension){
        
        float x=uDimension.at(0);
        
        float y=uDimension.at(2);
        
        float z=uDimension.at(1);
        
        U4DVector3n modelDimension(x,y,z);
        
        uModel->bodyCoordinates.setModelDimension(modelDimension);
        
    }
        
    void U4DMeshAssetLoader::loadEntityMatrixSpace(U4DEntity *uModel,std::vector<float> uLocalMatrix){
        
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

    void U4DMeshAssetLoader::loadMeshVerticesData(U4DModel *uModel,std::vector<float> uMeshVertices){
        
        for (int i=0; i<uMeshVertices.size();) {
            
            float x=uMeshVertices.at(i);
            
            float y=uMeshVertices.at(i+1);
            
            float z=uMeshVertices.at(i+2);
            
            U4DVector3n uMeshVertices(x,y,z);
            
            uModel->polygonInformation.addVertexToContainer(uMeshVertices);
            i=i+3;
            
        }
        
    }
        
    void U4DMeshAssetLoader::loadMeshEdgesData(U4DModel *uModel,std::vector<int> uMeshEdgesIndex){
        
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
        
    void U4DMeshAssetLoader::loadMeshFacesData(U4DModel *uModel,std::vector<int> uMeshFacesIndex){

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

    void U4DMeshAssetLoader::loadSpaceData(U4DMatrix4n &uMatrix, std::vector<float> uSpaceData){
        
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

    void U4DMeshAssetLoader::loadSpaceData(U4DDualQuaternion &uSpace, std::vector<float> uSpaceData){
        
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

    void U4DMeshAssetLoader::loadVertexBoneWeightsToBody(std::vector<float> &uVertexWeights,std::vector<float> uWeights){
        
        
        for (int i=0; i<uWeights.size();i++) {
         
            uVertexWeights.push_back(uWeights.at(i));
        }
        
    }

}
