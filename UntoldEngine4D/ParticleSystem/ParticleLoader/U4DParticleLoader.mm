//
//  U4DParticleLoader.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/1/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DParticleLoader.h"
#include <stdio.h>
#include <string.h>
#include <vector>
#include <sstream>
#include "CommonProtocols.h"
#include "U4DParticleSystem.h"
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
    
    U4DParticleLoader::U4DParticleLoader(){
        
    }
    
    U4DParticleLoader::~U4DParticleLoader(){
        
    }
    
    U4DParticleLoader* U4DParticleLoader::instance=0;
    
    U4DParticleLoader* U4DParticleLoader::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DParticleLoader();
        }
        
        return instance;
    }
    
    
    bool U4DParticleLoader::loadDigitalAssetFile(const char* uFile){
        
        //if file exists, simply return. no need to load the file again
        std::string uStringFile(uFile);
        if (currentLoadedFile.compare(uStringFile)==0) {
            
            return true;
            
        }
        
        bool loadOk=doc.LoadFile(uFile);
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if (!loadOk) {
            
            logger->log("Success: Digital Asset File %s succesfully Loaded.",uFile);
            
            currentLoadedFile=uFile;
            
            loadOk=true;
            
        }else{
            
            logger->log("Error: Couldn't load Digital Asset File, No file %s exist.",uFile);
            
            currentLoadedFile.clear();
            
            loadOk=false;
        }
        
        return loadOk;
    }
    
    
    bool U4DParticleLoader::loadAssetToMesh(U4DParticleSystem *uParticleSystem,std::string uMeshID){
        
        tinyxml2::XMLNode *root=doc.FirstChildElement("UntoldEngine");
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
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
                    
                    //Default number of polycount is 3000
                    
                    if (vertexCount<=director->getPolycount()*3 && indexCount%3==0) {
                        //The model can be processed since it is below 1000 vertices and it has been properly triangularized
                        
                        logger->log("In Process: Loading Digital Asset Data for model: %s",meshName.c_str());
                        
                        //inform that the model does exist
                        modelExist=true;
                        
                        tinyxml2::XMLElement *vertices=child->FirstChildElement("vertices");
                        tinyxml2::XMLElement *normal=child->FirstChildElement("normal");
                        tinyxml2::XMLElement *uv=child->FirstChildElement("uv");
                        tinyxml2::XMLElement *index=child->FirstChildElement("index");
                        tinyxml2::XMLElement *texture=child->FirstChildElement("texture_image");
                        tinyxml2::XMLElement *localMatrix=child->FirstChildElement("local_matrix");
                        tinyxml2::XMLElement *dimension=child->FirstChildElement("dimension");
                        
                        //Set name
                        uParticleSystem->setName(meshName);
                        
                        if (vertices!=NULL) {
                            
                            std::string data=vertices->GetText();
                            loadVerticesData(uParticleSystem, data);
                            
                        }
                        
                        if (normal!=NULL) {
                            
                            std::string data=normal->GetText();
                            loadNormalData(uParticleSystem, data);
                            
                        }
                        
                        if (uv!=NULL) {
                            
                            std::string data=uv->GetText();
                            loadUVData(uParticleSystem, data);
                            
                        }
                        
                        if (index!=NULL) {
                            
                            std::string data=index->GetText();
                            loadIndexData(uParticleSystem, data);
                            
                        }
                        
                        
                        if (dimension!=NULL) {
                            std::string data=dimension->GetText();
                            loadDimensionDataToBody(uParticleSystem, data);
                        }
                        
                        
                        if(texture!=NULL){
                            
                            std::string textureString=texture->GetText();
                            
                            uParticleSystem->textureInformation.setDiffuseTexture(textureString);
                            
                        }
                        
                        if (localMatrix!=NULL) {
                            
                            std::string bodyTransformatioMatrix=localMatrix->GetText();
                            loadEntityMatrixSpace(uParticleSystem,bodyTransformatioMatrix);
                        }
                        
                        
                    }else if(vertexCount>director->getPolycount()*3 && indexCount%3!=0){
                        
                        logger->log("Error: The vertex count for %s is above the acceptable range. Decrease the vertex count to about 3000 polys. If you want, you can change this value using setPolycount method in the U4DDirector class. However, keep in mind that the higher the polycount, the slower the rendering. \nAlso, the character has not been properly triangularized. Make sure not to use n-gons in your topology, and that there are no loose vertices. Make sure your model is designed using Mesh-Modeling techniques only.",meshName.c_str());
                        
                        return false;
                        
                    }else if(vertexCount>director->getPolycount()*3){
                        
                        logger->log("Error: The vertex count for %s is above the acceptable range. Decrease the vertex count to about 3000 polys. If you want, you can increase this value using setPolycount method in the U4DDirector class. However, keep in mind that the higher the polycount, the slower the rendering.",meshName.c_str());
                        
                        return false;
                        
                    }else if(indexCount%3!=0){
                        
                        logger->log("Error: The character %s has not been properly triangularized. Make sure not to use n-gons in your topology. Make sure your model is designed using Mesh-Modeling techniques only.",meshName.c_str());
                        
                        return false;
                    }
                    
                    
                }
                
            }
            
            
        }
        
        if (modelExist) {
            
            logger->log("Success: Digital Asset Data for model %s has been loaded into the engine.",uMeshID.c_str());
            
            return true;
        }
        
        logger->log("Error: No model with name %s exist.",uMeshID.c_str());
        
        return false;
        
    }
    
    
    void U4DParticleLoader::loadEntityMatrixSpace(U4DEntity *uParticleSystem,std::string uStringData){
        
        //    0    4    8    12
        //    1    5    9    13
        //    2    6    10    14
        //    3    7    11    15
        
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
        
        
        
        uParticleSystem->setLocalSpace(modelDualQuaternion);
        
    }
    
    void U4DParticleLoader::loadSpaceData(U4DDualQuaternion &uSpace, std::string uStringData){
        
        //    0    4    8    12
        //    1    5    9    13
        //    2    6    10    14
        //    3    7    11    15
        
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
    
    void U4DParticleLoader::loadSpaceData(U4DMatrix4n &uMatrix, std::string uStringData){
        
        //    0    4    8    12
        //    1    5    9    13
        //    2    6    10    14
        //    3    7    11    15
        
        std::vector<float> tempVector;
        
        
        stringToFloat(uStringData, &tempVector);
        
        uMatrix.matrixData[0]=tempVector.at(0);
        uMatrix.matrixData[4]=tempVector.at(1);
        uMatrix.matrixData[8]=tempVector.at(2);
        uMatrix.matrixData[12]=tempVector.at(3);
        
        uMatrix.matrixData[1]=tempVector.at(4);
        uMatrix.matrixData[5]=tempVector.at(5);
        uMatrix.matrixData[9]=tempVector.at(6);
        uMatrix.matrixData[13]=tempVector.at(7);
        
        uMatrix.matrixData[2]=tempVector.at(8);
        uMatrix.matrixData[6]=tempVector.at(9);
        uMatrix.matrixData[10]=tempVector.at(10);
        uMatrix.matrixData[14]=tempVector.at(11);
        
        uMatrix.matrixData[3]=tempVector.at(12);
        uMatrix.matrixData[7]=tempVector.at(13);
        uMatrix.matrixData[11]=tempVector.at(14);
        uMatrix.matrixData[15]=tempVector.at(15);
        
    }
    
    
    
    void U4DParticleLoader::loadVerticesData(U4DParticleSystem *uParticleSystem,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            float x=tempVector.at(i);
            
            float y=tempVector.at(i+1);
            
            float z=tempVector.at(i+2);
            
            U4DVector3n uVertices(x,y,z);
            
            uParticleSystem->bodyCoordinates.addVerticesDataToContainer(uVertices);
            i=i+3;
            
        }
        
    }
    
    void U4DParticleLoader::loadNormalData(U4DParticleSystem *uParticleSystem,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            float n1=tempVector.at(i);
            
            float n2=tempVector.at(i+1);
            
            float n3=tempVector.at(i+2);
            
            U4DVector3n Normal(n1,n2,n3);
            
            uParticleSystem->bodyCoordinates.addNormalDataToContainer(Normal);
            i=i+3;
            
        }
        
    }
    
    void U4DParticleLoader::loadUVData(U4DParticleSystem *uParticleSystem,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            
            float s=tempVector.at(i);
            
            float t=tempVector.at(i+1);
            
            U4DVector2n UV(s,t);
            
            uParticleSystem->bodyCoordinates.addUVDataToContainer(UV);
            i=i+2;
            
        }
        
    }
    
    
    void U4DParticleLoader::loadIndexData(U4DParticleSystem *uParticleSystem,std::string uStringData){
        
        std::vector<int> tempVector;
        
        stringToInt(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            int i1=tempVector.at(i);
            int i2=tempVector.at(i+1);
            int i3=tempVector.at(i+2);
            
            U4DIndex index(i1,i2,i3);
            
            uParticleSystem->bodyCoordinates.addIndexDataToContainer(index);
            
            i=i+3;
        }
        
    }
    
    void U4DParticleLoader::loadDimensionDataToBody(U4DParticleSystem *uParticleSystem,std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        float x=tempVector.at(0);
        
        float y=tempVector.at(2);
        
        float z=tempVector.at(1);
        
        U4DVector3n uDimension(x,y,z);
        
        uParticleSystem->bodyCoordinates.setModelDimension(uDimension);
        
    }
    
    
    void U4DParticleLoader::stringToFloat(std::string uStringData,std::vector<float> *uFloatData){
        
        std::stringstream stringToParse(uStringData);
        
        std::string outString;
        
        while (getline(stringToParse, outString, ' ')) {
            
            std::istringstream iss(outString);
            
            float c=stof(outString);
            
            uFloatData->push_back(c);
            
        }
        
    }
    
    void U4DParticleLoader::stringToInt(std::string uStringData,std::vector<int> *uIntData){
        
        std::stringstream stringToParse(uStringData);
        
        std::string outString;
        
        while (getline(stringToParse, outString, ' ')) {
            
            std::istringstream iss(outString);
            
            int c=stoi(outString);
            
            uIntData->push_back(c);
            
        }
        
    }
    
}
