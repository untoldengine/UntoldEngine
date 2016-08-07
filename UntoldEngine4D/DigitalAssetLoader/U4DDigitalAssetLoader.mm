//
//  U4DDigitalAssetLoader.cpp
//  ColladaLoader
//
//  Created by Harold Serrano on 5/28/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DDigitalAssetLoader.h"
#include <stdio.h>
#include <string.h>
#include <vector>
#include <sstream>
#include "CommonProtocols.h"
#include "U4DModel.h"
#include "U4DMatrix4n.h"
#include "U4DVector4n.h"
#include "U4DSegment.h"
#include "U4DArmatureData.h"
#include "U4DBoneData.h"
#include "U4DAnimation.h"
#include "U4DLights.h"

namespace U4DEngine {
    
    U4DDigitalAssetLoader::U4DDigitalAssetLoader(){
        
    }

    U4DDigitalAssetLoader::~U4DDigitalAssetLoader(){
        
    }

    U4DDigitalAssetLoader* U4DDigitalAssetLoader::instance=0;

    U4DDigitalAssetLoader* U4DDigitalAssetLoader::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DDigitalAssetLoader();
        }
        
        return instance;
    }


    bool U4DDigitalAssetLoader::loadDigitalAssetFile(const char* uFile){
        
        bool loadOk=doc.LoadFile(uFile);
        
        if (!loadOk) {
            std::cout<<"Digital Asset File Loaded"<<std::endl;
            loadOk=true;
            
        }else{
            std::cout<<"oops, no Digital Asset File";
            loadOk=false;
        }
        
        return loadOk;
    }


    bool U4DDigitalAssetLoader::loadAssetToMesh(U4DModel *uModel,std::string uMeshID){
        
        tinyxml2::XMLNode *root=doc.FirstChildElement("UntoldEngine");
        
        bool modelExist=false;
        
        //Get Mesh ID
        tinyxml2::XMLElement *node=root->FirstChildElement("asset")->FirstChildElement("meshes");
        
        if (node!=NULL) {
            
            for (tinyxml2::XMLElement *child=node->FirstChildElement("mesh"); child!=NULL; child=child->NextSiblingElement("mesh")) {
                
                
                std::string meshName=child->Attribute("name");
                
                std::string vertexCountString=child->Attribute("vertex_count");
                std::string indexCountString=child->Attribute("index_count");
                
                //convert both vertex and index count to integers
                
                int vertexCount=stoi(vertexCountString);
                int indexCount=stoi(indexCountString);
                
                if (meshName.compare(uMeshID)==0) {
                 
                //MAXIMUM number of verts: 1538, Tris=3072, Faces: 3072.
                //Becasue of the algorithm used the MAX vertex count is 3072*3
                if (vertexCount<=9000 && indexCount%3==0) {
                    //The model can be processed since it is below 1000 vertices and it has been properly triangularized
                    
                    std::cout<<"Loading model: "<<meshName<<std::endl;
                    
                    //inform that the model does exist
                    modelExist=true;
                    
                    tinyxml2::XMLElement *vertices=child->FirstChildElement("vertices");
                    tinyxml2::XMLElement *normal=child->FirstChildElement("normal");
                    tinyxml2::XMLElement *uv=child->FirstChildElement("uv");
                    tinyxml2::XMLElement *index=child->FirstChildElement("index");
                    tinyxml2::XMLElement *materialIndex=child->FirstChildElement("material_index");
                    tinyxml2::XMLElement *diffuseColor=child->FirstChildElement("diffuse_color");
                    tinyxml2::XMLElement *specularColor=child->FirstChildElement("specular_color");
                    tinyxml2::XMLElement *diffuseIntensity=child->FirstChildElement("diffuse_intensity");
                    tinyxml2::XMLElement *specularIntensity=child->FirstChildElement("specular_intensity");
                    tinyxml2::XMLElement *specularHardness=child->FirstChildElement("specular_hardness");
                    tinyxml2::XMLElement *texture=child->FirstChildElement("texture_image");
                    tinyxml2::XMLElement *localMatrix=child->FirstChildElement("local_matrix");
                    tinyxml2::XMLElement *armature=child->FirstChildElement("armature");
                    tinyxml2::XMLElement *dimension=child->FirstChildElement("dimension");
                    
                    //Set name
                    uModel->setName(meshName);
                    
                    if (vertices!=NULL) {
                        
                        std::string data=vertices->GetText();
                        loadVerticesData(uModel, data);
                        
                    }
                    
                    if (normal!=NULL) {
                        
                        std::string data=normal->GetText();
                        loadNormalData(uModel, data);
                        
                    }
                    
                    if (uv!=NULL) {
                        
                        std::string data=uv->GetText();
                        loadUVData(uModel, data);
                        
                        //calculate tangent vector only if model has UV data
                        
                        if(uModel->bodyCoordinates.uVContainer.size()>0){
                            loadTangentDataToBody(uModel);
                        }
                        
                    }
                    
                    if (index!=NULL) {
                        
                        std::string data=index->GetText();
                        loadIndexData(uModel, data);
                        
                    }
                    
                    if (dimension!=NULL) {
                        std::string data=dimension->GetText();
                        loadDimensionDataToBody(uModel, data);
                    }
                    
                    if (materialIndex!=NULL) {
                        
                        std::string data=materialIndex->GetText();
                        loadMaterialIndexData(uModel, data);
                        uModel->setHasMaterial(true);
                        
                    }
                    
                    if (diffuseColor!=NULL) {
                        
                        std::string diffuseColorString=diffuseColor->GetText();
                        loadDiffuseColorData(uModel, diffuseColorString);
                        
                    }
                    
                    
                    if (specularColor!=NULL) {
                        
                        std::string specularColorString=specularColor->GetText();
                        loadSpecularColorsData(uModel, specularColorString);
                        
                    }
                    
                    if (diffuseIntensity!=NULL) {
                        
                        std::string diffuseIntensityString=diffuseIntensity->GetText();
                        loadDiffuseIntensityData(uModel, diffuseIntensityString);
                        
                    }
                    
                    if (specularIntensity!=NULL) {
                        
                        std::string specularIntensityString=specularIntensity->GetText();
                        loadSpecularIntensityData(uModel, specularIntensityString);
                        
                    }
                    
                    if (specularHardness!=NULL) {
                        
                        std::string specularHardnessString=specularHardness->GetText();
                        loadSpecularHardnessData(uModel, specularHardnessString);
                        
                    }
                    
                    if(texture!=NULL){
                        
                        std::string textureString=texture->GetText();
                        
                        uModel->textureInformation.setDiffuseTexture(textureString);
                        
                        uModel->setHasTexture(true);
                        
                    }
                    
                    if (localMatrix!=NULL) {
                        
                        std::string bodyTransformatioMatrix=localMatrix->GetText();
                        loadEntityMatrixSpace(uModel,bodyTransformatioMatrix);
                    }
                    
                    if (armature!=NULL) {
                        
                        //if model has armature, then change the shading
                        
                        uModel->openGlManager->setShader("AnimationShader");
                        
                        //read the Bind Shape Matrix
                        tinyxml2::XMLElement *bindShapeMatrix=armature->FirstChildElement("bind_shape_matrix");
                        
                        if (bindShapeMatrix!=NULL) {
                            std::string bindShapeMatrixString=bindShapeMatrix->GetText();
                            
                            loadMatrixToBody(uModel->armatureManager->bindShapeSpace, bindShapeMatrixString);
                            
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
                                    
                                    loadMatrixToBody(rootBone->localSpace, matrixLocalString);
                                }
                                
                                //add the bind pose Matrix
                                
                                tinyxml2::XMLElement *bindPoseMatrix=bone->FirstChildElement("bind_pose_matrix");
                                if (bindPoseMatrix!=NULL) {
                                    
                                    std::string bindPoseMatrixString=bindPoseMatrix->GetText();
                                    
                                    loadMatrixToBody(rootBone->bindPoseSpace, bindPoseMatrixString);
                                }
                                
                                //add the bind pose inverse matrix
                                
                                tinyxml2::XMLElement *bindPoseInverseMatrix=bone->FirstChildElement("inverse_bind_pose_matrix");
                                
                                if (bindPoseInverseMatrix!=NULL) {
                                    
                                    std::string bindPoseInverseMatrixString=bindPoseInverseMatrix->GetText();
                                   
                                    loadMatrixToBody(rootBone->inverseBindPoseSpace, bindPoseInverseMatrixString);
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
                                    
                                    loadMatrixToBody(childBone->localSpace, matrixLocalString);
                                }
                                
                                //add the bind pose Matrix
                                
                                tinyxml2::XMLElement *bindPoseMatrix=bone->FirstChildElement("bind_pose_matrix");
                                if (bindPoseMatrix!=NULL) {
                                    
                                    std::string bindPoseMatrixString=bindPoseMatrix->GetText();
                                    
                                    loadMatrixToBody(childBone->bindPoseSpace, bindPoseMatrixString);
                                }
                                
                                //add the bind pose inverse matrix
                                
                                tinyxml2::XMLElement *bindPoseInverseMatrix=bone->FirstChildElement("inverse_bind_pose_matrix");
                                
                                if (bindPoseInverseMatrix!=NULL) {
                                    
                                    std::string bindPoseInverseMatrixString=bindPoseInverseMatrix->GetText();
                                    
                                    loadMatrixToBody(childBone->inverseBindPoseSpace, bindPoseInverseMatrixString);
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
                    
                
                }else if(vertexCount>9000 && indexCount%3!=0){
                    std::cout<<"The vertex count for  "<<meshName<<"  is above the acceptable range. Decrease the vertex count to below 1500\nAlso, the character has not been properly triangularized. Make sure not to use n-gons in your topology, and that there are no loose vertices. Make sure your model is designed using Mesh-Modeling techniques only."<<std::endl;
                    
                    return false;
                    
                }else if(vertexCount>9000){
                    std::cout<<"The vertex count for "<<meshName<<" is above the acceptable range. Decrease the vertex count to below 1500."<<std::endl;
                    
                    return false;
                    
                }else if(indexCount%3!=0){
                    std::cout<<"The character "<<meshName<<" has not been properly triangularized. Make sure not to use n-gons in your topology. Make sure your model is designed using Mesh-Modeling techniques only."<<std::endl;
                    
                    return false;
                }
             
                   
            }
                
        }
            
    
      }
        
        if (modelExist) {
            return true;
        }
        
        std::cout<<"No model with name "<<uMeshID<<" exist"<<std::endl;
        
        return false;
        
    }


    void U4DDigitalAssetLoader::loadEntityMatrixSpace(U4DEntity *uModel,std::string uStringData){
        
        //	0	4	8	12
        //	1	5	9	13
        //	2	6	10	14
        //	3	7	11	15
        
        std::vector<float> tempVector;
        U4DMatrix4n tempMatrix;
        
        stringToFloat(uStringData, &tempVector);
        
        tempMatrix.matrixData[0]=tempVector.at(0);
        tempMatrix.matrixData[4]=tempVector.at(1);
        tempMatrix.matrixData[8]=tempVector.at(2);
        tempMatrix.matrixData[12]=tempVector.at(3);
        
        tempMatrix.matrixData[1]=tempVector.at(4);
        tempMatrix.matrixData[5]=tempVector.at(5);
        tempMatrix.matrixData[9]=tempVector.at(6);
        tempMatrix.matrixData[13]=tempVector.at(7);
        
        tempMatrix.matrixData[2]=tempVector.at(8);
        tempMatrix.matrixData[6]=tempVector.at(9);
        tempMatrix.matrixData[10]=tempVector.at(10);
        tempMatrix.matrixData[14]=tempVector.at(11);
        
        tempMatrix.matrixData[3]=tempVector.at(12);
        tempMatrix.matrixData[7]=tempVector.at(13);
        tempMatrix.matrixData[11]=tempVector.at(14);
        tempMatrix.matrixData[15]=tempVector.at(15);
        
        
        U4DDualQuaternion modelDualQuaternion;
        modelDualQuaternion.transformMatrix4nToDualQuaternion(tempMatrix);
        
        
         /*THIS BLENDER TO OPENGL CONVERTION IS NOW IMPLEMENTED IN THE BLENDER SCRIPT LOAD
        //NO NEED TO DO IT HERE ANYMORE
         //===============================================================================
        
        //multiply the matrix to align it with opengl coordinate system
        
        //From Mathematica
        //RotX = RotationMatrix[90 Degree, {1, 0, 0}]
        //{{1, 0, 0}, {0, 0, -1}, {0, 1, 0}}
        //S = {{1, 0, 0}, {0, 1, 0}, {0, 0, -1}};
        //coordSystemMatrix = S.RotX.S
        
        
        // Since we are getting our data from blender, we need to convert this matrix:
         
         (1,0,0,0,
         0,0,1,0,
         0,-1,0,0,
         0,0,0,1);
         
         //into a dual quaternion
         
        U4DVector3n realVector(-0.707107,0,0);
        U4DVector3n pureVector(0,0,0);
        
        U4DQuaternion realQuaternion(0.707107,realVector);
        U4DQuaternion pureQuaternion(0,pureVector);
        
        U4DDualQuaternion worldDualQuaternionTransform(realQuaternion,pureQuaternion);
        
        
        //transform the model dual quaternion by the world dual quaternion
        modelDualQuaternion=modelDualQuaternion*worldDualQuaternionTransform;
        */
        
        
        
        uModel->setLocalSpace(modelDualQuaternion);
        
    }

    void U4DDigitalAssetLoader::loadMatrixToBody(U4DDualQuaternion &uSpace, std::string uStringData){
        
        //	0	4	8	12
        //	1	5	9	13
        //	2	6	10	14
        //	3	7	11	15
        
        std::vector<float> tempVector;
        U4DMatrix4n tempMatrix;
        
        stringToFloat(uStringData, &tempVector);
        
        tempMatrix.matrixData[0]=tempVector.at(0);
        tempMatrix.matrixData[4]=tempVector.at(1);
        tempMatrix.matrixData[8]=tempVector.at(2);
        tempMatrix.matrixData[12]=tempVector.at(3);
        
        tempMatrix.matrixData[1]=tempVector.at(4);
        tempMatrix.matrixData[5]=tempVector.at(5);
        tempMatrix.matrixData[9]=tempVector.at(6);
        tempMatrix.matrixData[13]=tempVector.at(7);
        
        tempMatrix.matrixData[2]=tempVector.at(8);
        tempMatrix.matrixData[6]=tempVector.at(9);
        tempMatrix.matrixData[10]=tempVector.at(10);
        tempMatrix.matrixData[14]=tempVector.at(11);
        
        tempMatrix.matrixData[3]=tempVector.at(12);
        tempMatrix.matrixData[7]=tempVector.at(13);
        tempMatrix.matrixData[11]=tempVector.at(14);
        tempMatrix.matrixData[15]=tempVector.at(15);
        
        
        uSpace.transformMatrix4nToDualQuaternion(tempMatrix);
        
    }



    void U4DDigitalAssetLoader::loadVerticesData(U4DModel *uModel,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            float x=tempVector.at(i);
            
            float y=tempVector.at(i+1);
            
            float z=tempVector.at(i+2);
            
            U4DVector3n uVertices(x,y,z);
            
            uModel->bodyCoordinates.addVerticesDataToContainer(uVertices);
            i=i+3;
            
        }
        
    }

    void U4DDigitalAssetLoader::loadNormalData(U4DModel *uModel,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            float n1=tempVector.at(i);
            
            float n2=tempVector.at(i+1);
            
            float n3=tempVector.at(i+2);
            
            U4DVector3n Normal(n1,n2,n3);
            
            uModel->bodyCoordinates.addNormalDataToContainer(Normal);
            i=i+3;
            
        }
        
    }

    void U4DDigitalAssetLoader::loadUVData(U4DModel *uModel,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            
            float s=tempVector.at(i);
            
            float t=tempVector.at(i+1);
            
            U4DVector2n UV(s,t);
            
            uModel->bodyCoordinates.addUVDataToContainer(UV);
            i=i+2;
            
        }
        
    }

    void U4DDigitalAssetLoader::loadIndexData(U4DModel *uModel,std::string uStringData){
        
        std::vector<int> tempVector;
        
        stringToInt(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            int i1=tempVector.at(i);
            int i2=tempVector.at(i+1);
            int i3=tempVector.at(i+2);
            
            U4DIndex index(i1,i2,i3);
            
            uModel->bodyCoordinates.addIndexDataToContainer(index);
            
            i=i+3;
        }
        
    }
    
    void U4DDigitalAssetLoader::loadDimensionDataToBody(U4DModel *uModel,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        float x=tempVector.at(0);
        
        float y=tempVector.at(1);
        
        float z=tempVector.at(2);
        
        U4DVector3n uDimension(x,y,z);
        
        uModel->bodyCoordinates.setModelDimension(uDimension);
        
    }

    void U4DDigitalAssetLoader::loadTangentDataToBody(U4DModel *uModel){
        
        U4DVector3n *tan1=new U4DVector3n[2*uModel->bodyCoordinates.verticesContainer.size()];
        U4DVector3n *tan2=new U4DVector3n[2*uModel->bodyCoordinates.verticesContainer.size()];
        
        for (int i=0; i<uModel->bodyCoordinates.indexContainer.size();i++) {
            
            int i1=uModel->bodyCoordinates.indexContainer.at(i).x;
            int i2=uModel->bodyCoordinates.indexContainer.at(i).y;
            int i3=uModel->bodyCoordinates.indexContainer.at(i).z;
            
            
            U4DVector3n v1=uModel->bodyCoordinates.verticesContainer.at(i1);
            
            
            U4DVector3n v2=uModel->bodyCoordinates.verticesContainer.at(i2);
            
            
            U4DVector3n v3=uModel->bodyCoordinates.verticesContainer.at(i3);
            
            //get the uv
            
            U4DVector2n w1=uModel->bodyCoordinates.uVContainer.at(i1);
            
            
            U4DVector2n w2=uModel->bodyCoordinates.uVContainer.at(i2);
            
            
            U4DVector2n w3=uModel->bodyCoordinates.uVContainer.at(i3);
            
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
        
        for (int a=0; a<uModel->bodyCoordinates.normalContainer.size(); a++) {
            
            
            
            U4DVector3n n=uModel->bodyCoordinates.normalContainer.at(a);
            
            U4DVector3n t=tan1[a];
            
            //Gram-Schmidt orthogonalize
            
            U4DVector3n nt=(t-n*n.dot(t));
            nt.normalize();
            
            //calculate handedness
            
            //h.w=(n.cross(t).dot(tan2[a])<0.0) ? -1.0:1.0;
            float handedness=(n.cross(t).dot(tan2[a])<0.0) ? -1.0:1.0;
            
            U4DVector4n h(nt.x,nt.y,nt.z,handedness);
            
            uModel->bodyCoordinates.addTangetDataToContainer(h);
        
        }
        
        delete[] tan1;
        delete[] tan2;
    }
    
    void U4DDigitalAssetLoader::loadMaterialIndexData(U4DModel *uModel,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size(); i++) {
            
            float materialIndex=tempVector.at(i);
            
            uModel->materialInformation.addMaterialIndexDataToContainer(materialIndex);
            
        }
        
    }

    void U4DDigitalAssetLoader::loadDiffuseColorData(U4DModel *uModel,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            float x=tempVector.at(i);
            
            float y=tempVector.at(i+1);
            
            float z=tempVector.at(i+2);
            
            float a=tempVector.at(i+3);
            
            U4DColorData uDiffuseColor(x,y,z,a);
            
            uModel->materialInformation.addDiffuseMaterialDataToContainer(uDiffuseColor);
            
            i=i+4;
            
        }
        
    }
    
    void U4DDigitalAssetLoader::loadSpecularColorsData(U4DModel *uModel,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            float x=tempVector.at(i);
            
            float y=tempVector.at(i+1);
            
            float z=tempVector.at(i+2);
            
            float a=tempVector.at(i+3);
            
            U4DColorData uSpecularColor(x,y,z,a);
            
            uModel->materialInformation.addSpecularMaterialDataToContainer(uSpecularColor);
            
            i=i+4;
            
        }
        
    }
    
    
    void U4DDigitalAssetLoader::loadDiffuseIntensityData(U4DModel *uModel,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();i++) {
            
            float diffuseIntensity=tempVector.at(i);
            uModel->materialInformation.addDiffuseIntensityMaterialDataToContainer(diffuseIntensity);
            
        }
        
    }
    
    void U4DDigitalAssetLoader::loadSpecularIntensityData(U4DModel *uModel,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();i++) {
            
            float specularIntensity=tempVector.at(i);
            uModel->materialInformation.addSpecularIntensityMaterialDataToContainer(specularIntensity);
            
        }
        
    }
    
    void U4DDigitalAssetLoader::loadSpecularHardnessData(U4DModel *uModel,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();i++) {
            
            float specularHardness=tempVector.at(i);
            uModel->materialInformation.addSpecularHardnessMaterialDataToContainer(specularHardness);
            
        }
        
    }

    void U4DDigitalAssetLoader::stringToFloat(std::string uStringData,std::vector<float> *uFloatData){
        
        std::stringstream stringToParse(uStringData);
        
        std::string outString;
        
        while (getline(stringToParse, outString, ' ')) {
            
            std::istringstream iss(outString);
            
            float c=stof(outString);
            
            uFloatData->push_back(c);
            
        }
        
    }

    void U4DDigitalAssetLoader::stringToInt(std::string uStringData,std::vector<int> *uIntData){
        
        std::stringstream stringToParse(uStringData);
        
        std::string outString;
        
        while (getline(stringToParse, outString, ' ')) {
            
            std::istringstream iss(outString);
            
            int c=stoi(outString);
            
            uIntData->push_back(c);
            
        }
        
    }

    void U4DDigitalAssetLoader::loadVertexBoneWeightsToBody(std::vector<float> &uVertexWeights,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();i++) {
         
            uVertexWeights.push_back(tempVector.at(i));
        }
        
    }

    void U4DDigitalAssetLoader::loadAnimationToMesh(U4DAnimation *uAnimation,std::string uAnimationName){
        
        tinyxml2::XMLNode *root=doc.FirstChildElement("UntoldEngine");
        int keyframeRange=0;
        
        //Get Mesh ID
        tinyxml2::XMLElement *node=root->FirstChildElement("asset")->FirstChildElement("meshes");
        if (node!=NULL) {
            
            for (tinyxml2::XMLElement *child=node->FirstChildElement("mesh"); child!=NULL; child=child->NextSiblingElement("mesh")) {
                
                std::string meshName=child->Attribute("name");
                
                if (meshName.compare(uAnimation->u4dModel->getName())==0) {
                    
                    tinyxml2::XMLElement *animations=child->FirstChildElement("animations");
                    
                    
                    if (animations!=NULL) {
                        
                        //iterate through all bones
                        
                        //get parent bone
                        U4DBoneData* boneChild = uAnimation->rootBone;
                        
                        //While there are still bones
                        while (boneChild!=0) {
                            
                            //iterate through all animations
                            for (tinyxml2::XMLElement *animationChild=animations->FirstChildElement("animation"); animationChild!=NULL; animationChild=animationChild->NextSiblingElement("animation")) {
                                
                                //get animation name
                                std::string animationName=animationChild->Attribute("name");
                                std::string animationFPS=animationChild->Attribute("fps");
                                
                                AnimationData animationData;
                                
                                //set animation name
                                animationData.name=animationName;
                                
                                uAnimation->name=animationName;
                                
                                //set animation fps
                                uAnimation->fps=stof(animationFPS);
                                
                                //iterate through all the keyframes
                                
                                keyframeRange=0;
                                
                                for (tinyxml2::XMLElement *keyframe=animationChild->FirstChildElement("keyframe"); keyframe!=NULL; keyframe=keyframe->NextSiblingElement("keyframe")) {
                                    
                                    KeyframeData keyframeData;
                                    
                                    //get keyframe
                                    float time=std::stof(keyframe->Attribute("time"));
                                    
                                    //set keyframe time
                                    keyframeData.time=time;
                                    
                                    //set keyframe name
                                    std::string keyframeCountString=std::to_string(keyframeRange);
                                    
                                    std::string keyframeName="keyframe";
                                    keyframeName.append(keyframeCountString);
                                    
                                    keyframeData.name=keyframeName;
                                    
                                    keyframeRange++;
                                    
                                    
                                    //iterate through all the bone anim transformations
                                    
                                    for (tinyxml2::XMLElement *boneTransform=keyframe->FirstChildElement("pose_matrix"); boneTransform!=NULL; boneTransform=boneTransform->NextSiblingElement("pose_matrix")) {
                                        
                                        //get bone Pose name
                                        std::string boneAnimationName=boneTransform->Attribute("name");
                                        
                                        //compare bone names
                                        if (boneChild->name.compare(boneAnimationName)==0) {
                                            
                                            //get bone Pose transform
                                            std::string boneTransformString=boneTransform->GetText();
                                            
                                            U4DDualQuaternion animationMatrixSpace;
                                            
                                            loadMatrixToBody(animationMatrixSpace, boneTransformString);
                                            
                                            //load the bone pose transform
                                            
                                            keyframeData.animationSpaceTransform=animationMatrixSpace;
                                            
                                        }//end if
                                        
                                    }//end for
                                    
                                    //add keyframe into the animationdata container
                                    animationData.keyframes.push_back(keyframeData);
                                    
                                }//end for
                                
                                //Add the animation to the animation container
                                uAnimation->animationsContainer.push_back(animationData);
                                
                            }//end for
                            
                            //iterate to the next child
                            boneChild=boneChild->next;
                            
                        }//end while
                        
                    }//end if

                    
                }//end if
                
            }//end for
        
        }
        
        //store the keyframe range
        uAnimation->keyframeRange=keyframeRange;
        
    }

}
