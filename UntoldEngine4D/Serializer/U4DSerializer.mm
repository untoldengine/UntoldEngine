//
//  U4DSerializer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/6/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DSerializer.h"
#include <fstream> //for file i/o
#include <iomanip>
#include <cstdlib>
#include <sstream>
#include "U4DSceneManager.h"
#include "U4DEntityFactory.h"
#include "U4DScene.h"
#include "U4DWorld.h"
#include "U4DModel.h"
#include "U4DCamera.h"
#include "U4DDirectionalLight.h"
#include "U4DLogger.h"

namespace U4DEngine {

    U4DSerializer *U4DSerializer::instance=0;

    U4DSerializer::U4DSerializer(){
            
        }

    U4DSerializer::~U4DSerializer(){
            
        }

    U4DSerializer *U4DSerializer::sharedInstance(){
        
        if (instance==0) {
            
            instance=new U4DSerializer();
            
        }
        
        return instance;
    }

    bool U4DSerializer::serialize(std::string uFileName){
        
        prepareEntities();
        
        if(convertEntitiesToBinary(uFileName)){
            return true;
        }
        
        return false;
        
    }

    void U4DSerializer::prepareEntities(){
        
//        1. Read all the entities present in the scenegraph
        
        entitySerializeDataContainer.clear();
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        
        U4DScene *scene=sceneManager->getCurrentScene();
        
        U4DWorld *world=scene->getGameWorld();
        
        U4DEntity *child=world->next;
        
        while (child!=nullptr) {
            
            if (child->getEntityType()==U4DEngine::MODEL) {
                
                U4DModel *model=dynamic_cast<U4DModel*>(child);
                
                ENTITYSERIALIZEDATA entitySerializeData;
                
                entitySerializeData.name=model->getName();
                entitySerializeData.assetReferenceName=model->getAssetReferenceName();
                entitySerializeData.classType=model->getClassType();
                
                U4DVector3n pos=model->getAbsolutePosition();
                entitySerializeData.position.push_back(pos.x);
                entitySerializeData.position.push_back(pos.y);
                entitySerializeData.position.push_back(pos.z);
                
                U4DVector3n orientation=model->getAbsoluteOrientation();
                
                entitySerializeData.orientation.push_back(orientation.x);
                entitySerializeData.orientation.push_back(orientation.y);
                entitySerializeData.orientation.push_back(orientation.z);
                
                entitySerializeDataContainer.push_back(entitySerializeData);
                
            }
            
            child=child->next;
        }
        
    }

    bool U4DSerializer::convertEntitiesToBinary(std::string uFileName){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        std::ofstream file(uFileName,std::ios::out | std::ios::binary);
        
        if (!file) {
            logger->log("File %s does not exist",uFileName.c_str());
            return false;
        }
        
        //Write camera info
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DVector3n cameraPositionVector=camera->getAbsolutePosition();
        U4DVector3n cameraOrientationVector=camera->getAbsoluteOrientation();
        
        std::vector<float> cameraPosition{cameraPositionVector.x,cameraPositionVector.y,cameraPositionVector.z};
        std::vector<float> cameraOrientation{cameraOrientationVector.x,cameraOrientationVector.y,cameraOrientationVector.z};
        
        //Write the camera position
        int cameraPositionSize=(int)cameraPosition.size();
        file.write((char*)&cameraPositionSize,sizeof(int));
        file.write((char*)&cameraPosition[0],cameraPositionSize*sizeof(float));
        
        //Write the camera orientation
        int cameraOrientationSize=(int)cameraOrientation.size();
        file.write((char*)&cameraOrientationSize,sizeof(int));
        file.write((char*)&cameraOrientation[0],cameraOrientationSize*sizeof(float));
        
        //Write dir light info
        U4DDirectionalLight *light=U4DDirectionalLight::sharedInstance();
        U4DVector3n lightPositionVector=light->getAbsolutePosition();
        U4DVector3n lightOrientationVector=light->getAbsoluteOrientation();
        U4DVector3n lightDiffuseColorVector=light->getDiffuseColor();
        
        std::vector<float> lightPosition{lightPositionVector.x,lightPositionVector.y,lightPositionVector.z};
        std::vector<float> lightOrientation{lightOrientationVector.x,lightOrientationVector.y,lightOrientationVector.z};
        std::vector<float> lightDiffuseColor{lightDiffuseColorVector.x,lightDiffuseColorVector.y,lightDiffuseColorVector.z};
        
        //Write dir light pos
        int lightPositionSize=(int)lightPosition.size();
        file.write((char*)&lightPositionSize,sizeof(int));
        file.write((char*)&lightPosition[0],lightPositionSize*sizeof(float));
        
        //Write the light orientation
        int lightOrientationSize=(int)lightOrientation.size();
        file.write((char*)&lightOrientationSize,sizeof(int));
        file.write((char*)&lightOrientation[0],lightOrientationSize*sizeof(float));
        
        //Write the light diffuse color
        int lightDiffuseColorSize=(int)lightDiffuseColor.size();
        file.write((char*)&lightDiffuseColorSize,sizeof(int));
        file.write((char*)&lightDiffuseColor[0],lightDiffuseColorSize*sizeof(float));
        
        //Write the number of models
        int numberOfModelsSize=(int)entitySerializeDataContainer.size();
        file.write((char*)&numberOfModelsSize,sizeof(int));
        
        for(const auto &n: entitySerializeDataContainer){
            
            //write the names of our model
            size_t modelNameLen=n.name.size();
            file.write((char*)&modelNameLen,sizeof(modelNameLen));
            file.write((char*)&n.name[0],modelNameLen);
            
            //write the asset reference name of the model
            size_t modelAssetReferenceNameLen=n.assetReferenceName.size();
            file.write((char*)&modelAssetReferenceNameLen,sizeof(modelAssetReferenceNameLen));
            file.write((char*)&n.assetReferenceName[0],modelAssetReferenceNameLen);
            
            //Write the class type
            size_t modelClassTypeLen=n.classType.size();
            file.write((char*)&modelClassTypeLen,sizeof(modelClassTypeLen));
            file.write((char*)&n.classType[0],modelClassTypeLen);
            
            //Write the position
            int positionSize=(int)n.position.size();
            file.write((char*)&positionSize,sizeof(int));
            file.write((char*)&n.position[0],positionSize*sizeof(float));
            
            //Write the orientation
            int orientationSize=(int)n.orientation.size();
            file.write((char*)&orientationSize,sizeof(int));
            file.write((char*)&n.orientation[0],orientationSize*sizeof(float));
            
        }
        
        file.close();
        
        logger->log("Scene data was saved");
        
        return true;
    }

    

    bool U4DSerializer::deserialize(std::string uFileName){
        
        if(convertBinaryToEntities(uFileName)){
            unloadEntities();
            
            return true;
        }
        
        return false;

    }


    bool U4DSerializer::convertBinaryToEntities(std::string uFileName){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DDirectionalLight *light=U4DDirectionalLight::sharedInstance();
        
        entitySerializeDataContainer.clear();
        
        std::ifstream file(uFileName, std::ios::in | std::ios::binary );
        
        if(!file){
            
            logger->log("File %s does not exist",uFileName.c_str());
            
            return false;
            
        }
        
        file.seekg(0);
        
        logger->log("Scene data is being retrieved");
        
        //Read camera data
        
        std::vector<float> cameraPosition;
        std::vector<float> cameraOrientation;
        
        //Read the camera position
        int cameraPositionSize=0;
        file.read((char*)&cameraPositionSize,sizeof(int));
        std::vector<float> tempCameraPosition(cameraPositionSize,0);
        
        //copy temp data into the position vector
        cameraPosition=tempCameraPosition;
        file.read((char*)&cameraPosition[0], cameraPositionSize*sizeof(float));
        
        //Read the orientation
        int cameraOrientationSize=0;
        file.read((char*)&cameraOrientationSize,sizeof(int));
        std::vector<float> tempCameraOrientation(cameraOrientationSize,0);
        
        //copy temp data into the orientation vector
        cameraOrientation=tempCameraOrientation;
        file.read((char*)&cameraOrientation[0], cameraOrientationSize*sizeof(float));
        
        //Read light data
        std::vector<float> lightPosition;
        std::vector<float> lightOrientation;
        std::vector<float> lightDiffuseColor;
        
        //Read the light position
        int lightPositionSize=0;
        file.read((char*)&lightPositionSize,sizeof(int));
        std::vector<float> tempLightPosition(lightPositionSize,0);
        
        //copy temp data into the position vector
        lightPosition=tempLightPosition;
        file.read((char*)&lightPosition[0], lightPositionSize*sizeof(float));
        
        //Read the light orientation
        int lightOrientationSize=0;
        file.read((char*)&lightOrientationSize,sizeof(int));
        std::vector<float> tempLightOrientation(lightOrientationSize,0);
        
        //copy temp data into the orientation vector
        lightOrientation=tempLightOrientation;
        file.read((char*)&lightOrientation[0], lightOrientationSize*sizeof(float));
        
        //Read the light diffuse color
        int lightDiffuseColorSize=0;
        file.read((char*)&lightDiffuseColorSize,sizeof(int));
        std::vector<float> tempLightDiffuseColor(lightDiffuseColorSize,0);
        
        //copy temp data into the diffuse color vector
        lightDiffuseColor=tempLightDiffuseColor;
        file.read((char*)&lightDiffuseColor[0], lightDiffuseColorSize*sizeof(float));
        
        
        //set camera pos and orientation
        U4DVector3n cameraPositionVector(cameraPosition.at(0    ),cameraPosition.at(1),cameraPosition.at(2));

        U4DVector3n cameraOrientationVector(cameraOrientation.at(0    ),cameraOrientation.at(1),cameraOrientation.at(2));
        
        camera->translateTo(cameraPositionVector);
        camera->rotateTo(cameraOrientationVector.x, cameraOrientationVector.y, cameraOrientationVector.z);
        
        //set light pos and orientation
        U4DVector3n lightPositionVector(lightPosition.at(0    ),lightPosition.at(1),lightPosition.at(2));

        U4DVector3n lightOrientationVector(lightOrientation.at(0    ),lightOrientation.at(1),lightOrientation.at(2));
        
        U4DVector3n lightDiffuseColorVector(lightDiffuseColor.at(0    ),lightDiffuseColor.at(1),lightDiffuseColor.at(2));
        
        light->translateTo(lightPositionVector);
        light->rotateTo(lightOrientationVector.x, lightOrientationVector.y, lightOrientationVector.z);
        light->setDiffuseColor(lightDiffuseColorVector);
        
        //READ NUMBER OF Models IN SCENE
        int numberOfModelsSize=0;
        file.read((char*)&numberOfModelsSize,sizeof(int));
        
        
        for(int i=0;i<numberOfModelsSize;i++){
            
            ENTITYSERIALIZEDATA modelData;
            
            //Read the names of our model
            size_t modelNameLen=0;
            file.read((char*)&modelNameLen,sizeof(modelNameLen));
            modelData.name.resize(modelNameLen);
            file.read((char*)&modelData.name[0],modelNameLen);
            
            //Read the asset Reference name of our model
            size_t modelAssetReferenceNameLen=0;
            file.read((char*)&modelAssetReferenceNameLen,sizeof(modelAssetReferenceNameLen));
            modelData.assetReferenceName.resize(modelAssetReferenceNameLen);
            file.read((char*)&modelData.assetReferenceName[0],modelAssetReferenceNameLen);
            
            //Read the class type of the model
            size_t modelClassTypeLen=0;
            file.read((char*)&modelClassTypeLen,sizeof(modelClassTypeLen));
            modelData.classType.resize(modelClassTypeLen);
            file.read((char*)&modelData.classType[0],modelClassTypeLen);
            
            //Read the position
            int positionSize=0;
            file.read((char*)&positionSize,sizeof(int));
            std::vector<float> tempPosition(positionSize,0);
            
            //copy temp data into the position vector
            modelData.position=tempPosition;
            file.read((char*)&modelData.position[0], positionSize*sizeof(float));
            
            //Read the orientation
            int orientationSize=0;
            file.read((char*)&orientationSize,sizeof(int));
            std::vector<float> tempOrientation(orientationSize,0);
            
            //copy temp data into the orientation vector
            modelData.orientation=tempOrientation;
            file.read((char*)&modelData.orientation[0], orientationSize*sizeof(float));
            
            //load the data into the container
            entitySerializeDataContainer.push_back(modelData);
            
        }
        
        return true;
    }

    void U4DSerializer::unloadEntities(){
        
        //clear everything in the scenegraph
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DEntityFactory *entityFactory=U4DEntityFactory::sharedInstance();
        
        U4DScene *scene=sceneManager->getCurrentScene();
        
        U4DWorld *world=scene->getGameWorld();
        
        world->removeAllModelChildren();
        
        //Iterate through the container
        for(const auto &n:entitySerializeDataContainer){
            
            U4DVector3n pos(n.position.at(0),n.position.at(1),n.position.at(2));
            U4DVector3n orient(n.orientation.at(0),n.orientation.at(1),n.orientation.at(2));
            
            //Ask the factory class to create an instance of each object and load it into the world
            
            entityFactory->createModelInstanceFromDeserialization(n.assetReferenceName,n.name, n.classType,pos, orient); 
            
        }
        
    }

}
