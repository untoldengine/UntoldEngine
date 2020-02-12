//
//  U4DPackedDigitalAssetLoader.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DPackedDigitalAssetLoader.h"
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

namespace U4DEngine {

    U4DPackedDigitalAssetLoader::U4DPackedDigitalAssetLoader(){
        
    }

    U4DPackedDigitalAssetLoader::~U4DPackedDigitalAssetLoader(){
        
    }

    U4DPackedDigitalAssetLoader* U4DPackedDigitalAssetLoader::instance=0;

    U4DPackedDigitalAssetLoader* U4DPackedDigitalAssetLoader::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DPackedDigitalAssetLoader();
        }
        
        return instance;
    }

    bool U4DPackedDigitalAssetLoader::loadDigitalAssetBinaryData(std::string filepath){
        
        std::ifstream file(filepath, std::ios::in | std::ios::binary );
        
        if(!file){
            
            std::cerr<<"no file";
            
            return false;
            
        }
        
        file.seekg(0);
        
        //READ NUMBER OF MESHES IN SCENE
        int numberOfMeshesSize=0;
        file.read((char*)&numberOfMeshesSize,sizeof(int));
        
        for(int i=0;i<numberOfMeshesSize;i++){
        
        MODELPACKED uModel;
        
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
        
         
         //READ PREHULL
         int prehullSize=0;
         file.read((char*)&prehullSize,sizeof(int));
         std::vector<float> tempPrehull(prehullSize,0);
         
         //copy temp to model2
         uModel.prehullVertices=tempPrehull;
         file.read((char*)&uModel.prehullVertices[0], prehullSize*sizeof(float));
         
         
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
                
                BONES bones;

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
        return true;
        
    }

    bool U4DPackedDigitalAssetLoader::loadAssetToMesh(U4DModel *uModel,std::string uMeshID){

        //find the model in the container
        
        for(auto n:modelsContainer){

            if (n.name.compare(uMeshID)==0) {
                
                //copy the data
                
                //NAME
                uModel->setName(n.name);
                
                //VERTICES
                loadVerticesData(uModel, n.vertices);
                
                //NORMALS
                loadNormalData(uModel, n.normals);
                
                //UVs
                loadUVData(uModel, n.uv);
                
                //INDEX
                loadIndexData(uModel, n.index);
                
                //PREHULL
                loadPreHullData(uModel, n.prehullVertices);
                
                //MATERIAL INDEX
                loadMaterialIndexData(uModel, n.materialIndex);
                
                //DIFFUSE COLOR
                loadDiffuseColorData(uModel, n.diffuseColor);
                
                //SPECULAR COLOR
                loadSpecularColorsData(uModel, n.specularColor);
                
                //DIFFUSE INTENSITY
                loadDiffuseIntensityData(uModel, n.diffuseIntensity);
                
                //SPECULAR INTENSITY
                loadSpecularIntensityData(uModel, n.specularIntensity);
                
                //SPECULAR HARDNESS
                loadSpecularHardnessData(uModel, n.specularHardness);
                
                //TEXTURE IMAGE
                if (n.textureNameSize>0) {
                    uModel->textureInformation.setDiffuseTexture(n.textureImage);
                }
                
                //LOCAL MATRIX
                loadEntityMatrixSpace(uModel, n.localMatrix);
                
                //DIMENSION
                loadDimensionDataToBody(uModel, n.dimension);
                
                //MESH VERTICES
                loadMeshVerticesData(uModel, n.meshVertices);
                
                //MESH EDGES INDEX
                loadMeshEdgesData(uModel, n.meshEdgesIndex);
                
                //MESH FACES INDEX
                loadMeshFacesData(uModel, n.meshFacesIndex);
                
                //LOAD ARMATURE
                if(n.armature.bones.size()>0){
                    
                    uModel->setHasArmature(true);
                    
                    //read the Bind Shape Matrix
                    loadSpaceData(uModel->armatureManager->bindShapeSpace, n.armature.bindShapeMatrix);
                    
                    //root bone
                    U4DBoneData *rootBone=NULL;
                    
                    //iterate through all the bones in the armature
                    for(auto b:n.armature.bones){
                        
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
                /*
                 
                 if (armature!=NULL) {
                 
                     uModel->setHasArmature(true);
                     
                     //read the Bind Shape Matrix
                     tinyxml2::XMLElement *bindShapeMatrix=armature->FirstChildElement("bind_shape_matrix");
                     
                     if (bindShapeMatrix!=NULL) {
                         std::string bindShapeMatrixString=bindShapeMatrix->GetText();
                         
                         loadSpaceData(uModel->armatureManager->bindShapeSpace, bindShapeMatrixString);
                         
                     }
                     
                     
                     //root bone
                     U4DBoneData *rootBone=NULL;
                     
                     //iterate through all the bones in the armature
                     for (tinyxml2::XMLElement *bone=armature->FirstChildElement("bone"); bone!=NULL; bone=bone->NextSiblingElement("bone")) {
                     
                         std::string boneParentName=bone->Attribute("parent");
                         std::string boneChildName=bone->Attribute("name");
                         
                         //bone is a root
                         if (boneParentName.compare("root")==0) {
                             
                             //if bone is root, then create a bone with parent set to root
                             rootBone=new U4DBoneData();
                             
                             rootBone->name=boneChildName;
                             
                             //add the local matrix
                             
                             tinyxml2::XMLElement *boneMatrixLocal=bone->FirstChildElement("local_matrix");
                             
                             if (boneMatrixLocal!=NULL) {
                                 
                                 std::string matrixLocalString=boneMatrixLocal->GetText();
                                 
                                 loadSpaceData(rootBone->localSpace, matrixLocalString);
                             }
                             
                             //add the bind pose Matrix
                             
                             tinyxml2::XMLElement *bindPoseMatrix=bone->FirstChildElement("bind_pose_matrix");
                             if (bindPoseMatrix!=NULL) {
                                 
                                 std::string bindPoseMatrixString=bindPoseMatrix->GetText();
                                 
                                 loadSpaceData(rootBone->bindPoseSpace, bindPoseMatrixString);
                             }
                             
                             //add the bind pose inverse matrix
                             
                             tinyxml2::XMLElement *bindPoseInverseMatrix=bone->FirstChildElement("inverse_bind_pose_matrix");
                             
                             if (bindPoseInverseMatrix!=NULL) {
                                 
                                 std::string bindPoseInverseMatrixString=bindPoseInverseMatrix->GetText();
                                
                                 loadSpaceData(rootBone->inverseBindPoseSpace, bindPoseInverseMatrixString);
                             }
                             
                            
                             //add the vertex weights
                             
                             tinyxml2::XMLElement *vertexWeights=bone->FirstChildElement("vertex_weights");
                             
                             if (vertexWeights!=NULL) {
                                 
                                 std::string vertexWeightsString=vertexWeights->GetText();
                                 
                                 loadVertexBoneWeightsToBody(rootBone->vertexWeightContainer, vertexWeightsString);
                             }
                             
                             
                             //add the bone to the U4DModel
                             uModel->armatureManager->setRootBone(rootBone);
                             
                         }else{ //bone is either a parent,child but not root
                             
                             
                             //1.look for the bone parent
                             
                             U4DBoneData *boneParent=rootBone->searchChildrenBone(boneParentName);
                             
                             //create the new bone
                             
                             U4DBoneData *childBone=new U4DBoneData();
                             
                             //set name
                             childBone->name=boneChildName;
                             
                             //add the local matrix
                             
                             tinyxml2::XMLElement *boneMatrixLocal=bone->FirstChildElement("local_matrix");
                             
                             if (boneMatrixLocal!=NULL) {
                                 
                                 std::string matrixLocalString=boneMatrixLocal->GetText();
                                 
                                 loadSpaceData(childBone->localSpace, matrixLocalString);
                             }
                             
                             //add the bind pose Matrix
                             
                             tinyxml2::XMLElement *bindPoseMatrix=bone->FirstChildElement("bind_pose_matrix");
                             if (bindPoseMatrix!=NULL) {
                                 
                                 std::string bindPoseMatrixString=bindPoseMatrix->GetText();
                                 
                                 loadSpaceData(childBone->bindPoseSpace, bindPoseMatrixString);
                             }
                             
                             //add the bind pose inverse matrix
                             
                             tinyxml2::XMLElement *bindPoseInverseMatrix=bone->FirstChildElement("inverse_bind_pose_matrix");
                             
                             if (bindPoseInverseMatrix!=NULL) {
                                 
                                 std::string bindPoseInverseMatrixString=bindPoseInverseMatrix->GetText();
                                 
                                 loadSpaceData(childBone->inverseBindPoseSpace, bindPoseInverseMatrixString);
                             }
                             
                             
                             
                             //add the vertex weights
                             
                             tinyxml2::XMLElement *vertexWeights=bone->FirstChildElement("vertex_weights");
                             
                             if (vertexWeights!=NULL) {
                                 
                                 std::string vertexWeightsString=vertexWeights->GetText();
                                 
                                 loadVertexBoneWeightsToBody(childBone->vertexWeightContainer, vertexWeightsString);
                             }
                             
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
                     
                 }//end if
                 
                 */
                
                
                return true;
            }
            
        }
        
        return false;
        
    }

    

    void U4DPackedDigitalAssetLoader::loadVerticesData(U4DModel *uModel,std::vector<float> uVertices){
        
        for (int i=0; i<uVertices.size();) {
            
            float x=uVertices.at(i);
            
            float y=uVertices.at(i+1);
            
            float z=uVertices.at(i+2);
            
            U4DVector3n uVertices(x,y,z);
            
            uModel->bodyCoordinates.addVerticesDataToContainer(uVertices);
            i=i+3;
            
        }
        
    }

    void U4DPackedDigitalAssetLoader::loadNormalData(U4DModel *uModel,std::vector<float> uNormals){

        
        for (int i=0; i<uNormals.size();) {
            
            float n1=uNormals.at(i);
            
            float n2=uNormals.at(i+1);
            
            float n3=uNormals.at(i+2);
            
            U4DVector3n Normal(n1,n2,n3);
            
            uModel->bodyCoordinates.addNormalDataToContainer(Normal);
            i=i+3;
            
        }
        
    }

    void U4DPackedDigitalAssetLoader::loadUVData(U4DModel *uModel,std::vector<float> uUV){
        
        for (int i=0; i<uUV.size();) {
            
            float s=uUV.at(i);
            
            float t=uUV.at(i+1);
            
            U4DVector2n UV(s,t);
            
            uModel->bodyCoordinates.addUVDataToContainer(UV);
            i=i+2;
            
        }
        
    }

    void U4DPackedDigitalAssetLoader::loadIndexData(U4DModel *uModel,std::vector<int> uIndex){
        
        for (int i=0; i<uIndex.size();) {
            
            int i1=uIndex.at(i);
            int i2=uIndex.at(i+1);
            int i3=uIndex.at(i+2);
            
            U4DIndex index(i1,i2,i3);
            
            uModel->bodyCoordinates.addIndexDataToContainer(index);
            
            i=i+3;
        }
        
    }

    void U4DPackedDigitalAssetLoader::loadPreHullData(U4DModel *uModel,std::vector<float> uPrehull){
        
        for (int i=0; i<uPrehull.size();) {
            
            float x=uPrehull.at(i);
            
            float y=uPrehull.at(i+1);
            
            float z=uPrehull.at(i+2);
            
            U4DVector3n uPreHullVertices(x,y,z);
            
            uModel->bodyCoordinates.addPreConvexHullVerticesDataToContainer(uPreHullVertices);
            i=i+3;
            
        }
    }

    void U4DPackedDigitalAssetLoader::loadMaterialIndexData(U4DModel *uModel,std::vector<int> uMaterialIndex){
        
        for (int i=0; i<uMaterialIndex.size(); i++) {
            
            float materialIndex=uMaterialIndex.at(i);
            
            uModel->materialInformation.addMaterialIndexDataToContainer(materialIndex);
            
        }
    }
        
    void U4DPackedDigitalAssetLoader::loadDiffuseColorData(U4DModel *uModel,std::vector<float> uDiffuseColor){
        
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
        
    void U4DPackedDigitalAssetLoader::loadSpecularColorsData(U4DModel *uModel,std::vector<float> uSpecularColor){
        
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
        
    void U4DPackedDigitalAssetLoader::loadDiffuseIntensityData(U4DModel *uModel,std::vector<float> uDiffuseIntensity){
        
        for (int i=0; i<uDiffuseIntensity.size();i++) {
            
            float diffuseIntensity=uDiffuseIntensity.at(i);
            uModel->materialInformation.addDiffuseIntensityMaterialDataToContainer(diffuseIntensity);
            
        }
        
    }
        
    void U4DPackedDigitalAssetLoader::loadSpecularIntensityData(U4DModel *uModel,std::vector<float> uSpecularIntesity){
        
        for (int i=0; i<uSpecularIntesity.size();i++) {
            
            float specularIntensity=uSpecularIntesity.at(i);
            uModel->materialInformation.addSpecularIntensityMaterialDataToContainer(specularIntensity);
            
        }
        
    }
        
    void U4DPackedDigitalAssetLoader::loadSpecularHardnessData(U4DModel *uModel,std::vector<float> uSpecularHardness){
        
        for (int i=0; i<uSpecularHardness.size();i++) {
            
            float specularHardness=uSpecularHardness.at(i);
            uModel->materialInformation.addSpecularHardnessMaterialDataToContainer(specularHardness);
            
        }
        
    }
        
    void U4DPackedDigitalAssetLoader::loadDimensionDataToBody(U4DModel *uModel,std::vector<float> uDimension){
        
        float x=uDimension.at(0);
        
        float y=uDimension.at(2);
        
        float z=uDimension.at(1);
        
        U4DVector3n modelDimension(x,y,z);
        
        uModel->bodyCoordinates.setModelDimension(modelDimension);
        
    }
        
    void U4DPackedDigitalAssetLoader::loadEntityMatrixSpace(U4DEntity *uModel,std::vector<float> uLocalMatrix){
        
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

    void U4DPackedDigitalAssetLoader::loadMeshVerticesData(U4DModel *uModel,std::vector<float> uMeshVertices){
        
        for (int i=0; i<uMeshVertices.size();) {
            
            float x=uMeshVertices.at(i);
            
            float y=uMeshVertices.at(i+1);
            
            float z=uMeshVertices.at(i+2);
            
            U4DVector3n uMeshVertices(x,y,z);
            
            uModel->polygonInformation.addVertexToContainer(uMeshVertices);
            i=i+3;
            
        }
        
    }
        
    void U4DPackedDigitalAssetLoader::loadMeshEdgesData(U4DModel *uModel,std::vector<int> uMeshEdgesIndex){
        
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
        
    void U4DPackedDigitalAssetLoader::loadMeshFacesData(U4DModel *uModel,std::vector<int> uMeshFacesIndex){

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

    void U4DPackedDigitalAssetLoader::loadSpaceData(U4DMatrix4n &uMatrix, std::vector<float> uSpaceData){
        
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

    void U4DPackedDigitalAssetLoader::loadSpaceData(U4DDualQuaternion &uSpace, std::vector<float> uSpaceData){
        
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

    void U4DPackedDigitalAssetLoader::loadVertexBoneWeightsToBody(std::vector<float> &uVertexWeights,std::vector<float> uWeights){
        
        
        for (int i=0; i<uWeights.size();i++) {
         
            uVertexWeights.push_back(uWeights.at(i));
        }
        
    }

}
