//
//  U4DSceneConfig.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/27/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DSceneConfig.h"
#include <sstream>
#include "U4DLogger.h"
#include "U4DSceneManager.h"
#include "U4DDynamicAction.h"
#include "U4DCamera.h"
#include "U4DDirectionalLight.h"
#include "U4DSerializer.h"

namespace U4DEngine {

    U4DSceneConfig *U4DSceneConfig::instance=0;

    U4DSceneConfig* U4DSceneConfig::sharedInstance(){
        
        if(instance==0){
            instance=new U4DSceneConfig();
        }
        
        return instance;
    }

    void U4DSceneConfig::applyPropertyToAllEntities(){
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        U4DWorld *world=scene->getGameWorld();
        
        tinyxml2::XMLElement *entities=root->FirstChildElement("Entities");
        
        for (tinyxml2::XMLElement *child=entities->FirstChildElement("entity"); child!=NULL; child=child->NextSiblingElement("entity")) {
         
            std::string entityName=child->Attribute("name");
            
            //search for child
            U4DEntity *entity=world->searchChild(entityName);
           
            //go into properties
            tinyxml2::XMLElement *properties=child->FirstChildElement("Properties");
            
            tinyxml2::XMLElement *kineticsElement=properties->FirstChildElement("Kinetics");
            tinyxml2::XMLElement *collisionElement=properties->FirstChildElement("Collision");
            
            //check if kinetics is enabled
            std::string kineticsEnabledString=kineticsElement->Attribute("enabled");
            bool kineticsEnabled=false;
            std::istringstream(kineticsEnabledString) >> kineticsEnabled;
            
            //check if collision is enabled
            std::string collisionEnabledString=collisionElement->Attribute("enabled");
            bool collisionEnabled=false;
            std::istringstream(collisionEnabledString)>>collisionEnabled;
            
            //if so, then get components values
            if (kineticsEnabled) {
                
                tinyxml2::XMLElement *gravityElement=kineticsElement->FirstChildElement("gravity");
                tinyxml2::XMLElement *massElement=kineticsElement->FirstChildElement("mass");
                
                //gravity
                std::string gravityValueString=gravityElement->GetText();
                std::vector<float> uData;
                stringToFloat(gravityValueString,&uData);
                
                U4DVector3n gravity=U4DVector3n(uData[0],uData[1],uData[2]);
                
                uData.clear();
                
                //mass
                std::string massValueString=massElement->GetText();
                stringToFloat(massValueString, &uData);
                
                float mass=uData[0];
                
                //enable kinetics and apply properties
                U4DModel *model=dynamic_cast<U4DModel*>(entity);
                U4DDynamicAction *kineticAction=new U4DDynamicAction(model);
                
                kineticAction->enableKineticsBehavior();
                kineticAction->setGravity(gravity);
                kineticAction->initMass(mass);
                
            }
            
            if(collisionEnabled){
                
                tinyxml2::XMLElement *restitutionElement=collisionElement->FirstChildElement("coefRestitution");
                tinyxml2::XMLElement *sensorElement=collisionElement->FirstChildElement("sensor");
                
                //coef of restitution
                std::string restitutionValueString=restitutionElement->GetText();
                std::vector<float> uData;
                stringToFloat(restitutionValueString,&uData);
                
                float coeffRest=uData[0];
                
                uData.clear();
                
                //sensor
                std::string sensorValueString=sensorElement->GetText();
                bool sensor=false;
                std::istringstream(sensorValueString) >> sensor;
                
                if (kineticsEnabled==false) {
                    //enable kinetics and apply properties
                    U4DModel *model=dynamic_cast<U4DModel*>(entity);
                    U4DDynamicAction *kineticAction=new U4DDynamicAction(model);
                    
                    kineticAction->enableCollisionBehavior();
                    kineticAction->initCoefficientOfRestitution(coeffRest);
                    kineticAction->setIsCollisionSensor(sensor);
                    
                    
                }else{
                    U4DDynamicAction *kineticAction=static_cast<U4DDynamicAction*>(entity->pDynamicAction);
                    
                    kineticAction->enableCollisionBehavior();
                    kineticAction->initCoefficientOfRestitution(coeffRest);
                    kineticAction->setIsCollisionSensor(sensor);
                }
                
            }
            
        }
        
    }

    void U4DSceneConfig::removePropertyFromAllEntities(){
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        U4DWorld *world=scene->getGameWorld();
        
        tinyxml2::XMLElement *entities=root->FirstChildElement("Entities");
        
        for (tinyxml2::XMLElement *child=entities->FirstChildElement("entity"); child!=NULL; child=child->NextSiblingElement("entity")) {
         
            std::string entityName=child->Attribute("name");
            
            //search for child
            U4DEntity *entity=world->searchChild(entityName);
            
            //delete kinetic object
            if (entity->pDynamicAction!=nullptr) {
                
                U4DDynamicAction *kineticAction=static_cast<U4DDynamicAction*>(entity->pDynamicAction);
                delete kineticAction;
                
            }
            
        }
    }

    U4DSceneConfig::U4DSceneConfig(){
        
        U4DSerializer *serializer=U4DSerializer::sharedInstance();
        
        root = serializer->xmlDoc.NewElement("UntoldEngine");
        root->SetAttribute("Version", "1.0");
        root->SetAttribute("Platform", "");
        serializer->xmlDoc.InsertFirstChild(root);
        
        tinyxml2::XMLElement* scene = serializer->xmlDoc.NewElement("Scene");
        scene->SetText("\n");
        root->LinkEndChild(scene);
        
        //camera
        tinyxml2::XMLElement* cameraElement=serializer->xmlDoc.NewElement("camera");
        cameraElement->SetText("\n");
        scene->InsertEndChild(cameraElement);

        {
            tinyxml2::XMLElement* cameraPos=serializer->xmlDoc.NewElement("position");
            cameraPos->SetText("0.0 0.0 0.0");
            cameraElement->InsertEndChild(cameraPos);

            tinyxml2::XMLElement* cameraOrientation=serializer->xmlDoc.NewElement("orientation");
            cameraOrientation->SetText("0.0 0.0 0.0");
            cameraElement->InsertEndChild(cameraOrientation);
        }

        //light
        tinyxml2::XMLElement* light=serializer->xmlDoc.NewElement("light");
        light->SetText("\n");
        scene->InsertEndChild(light);

        {
            tinyxml2::XMLElement* lightPos=serializer->xmlDoc.NewElement("position");
            lightPos->SetText("0.0 0.0 0.0");
            light->InsertEndChild(lightPos);

            tinyxml2::XMLElement* lightOrientation=serializer->xmlDoc.NewElement("orientation");
            lightOrientation->SetText("0.0 0.0 0.0");
            light->InsertEndChild(lightOrientation);

            tinyxml2::XMLElement* lightColor=serializer->xmlDoc.NewElement("color");
            lightColor->SetText("0.0 0.0 0.0");
            light->InsertEndChild(lightColor);
        }
        
        tinyxml2::XMLElement* entities = serializer->xmlDoc.NewElement("Entities");
        entities->SetAttribute("count", 0);
        entities->SetText("\n");
        root->LinkEndChild(entities);
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DVector3n cameraPosition=camera->getAbsolutePosition();
        U4DVector3n cameraOrientation=camera->getAbsoluteOrientation();
        float cameraPos[3]={cameraPosition.x,cameraPosition.y,cameraPosition.z};
        float cameraOrient[3]={cameraOrientation.x,cameraOrientation.y,cameraOrientation.z};
        
        setScenePropsBehavior("camera", "Scene", "position", &cameraPos[0],3);
        setScenePropsBehavior("camera", "Scene", "orientation", &cameraOrient[0],3);

        U4DDirectionalLight *dirLight=U4DDirectionalLight::sharedInstance();

        U4DVector3n lightPos=dirLight->getAbsolutePosition();
        U4DVector3n lightOrient=dirLight->getAbsoluteOrientation();
        U4DVector3n diffuseColor=dirLight->getDiffuseColor();

        float lightpos[3] = {lightPos.x,lightPos.y,lightPos.z};
        float lightorient[3]={lightOrient.x,lightOrient.y,lightOrient.z};
        float color[3] = {diffuseColor.x,diffuseColor.y,diffuseColor.z};

        setScenePropsBehavior("light", "Scene", "position", &lightpos[0],3);
       
        setScenePropsBehavior("light", "Scene", "orientation", &lightorient[0],3);
       
        setScenePropsBehavior("light", "Scene", "color", &color[0],3);
       
    }

    U4DSceneConfig::~U4DSceneConfig(){
        
    }

    int U4DSceneConfig::getEntitiesCount(){
        
        tinyxml2::XMLElement *entities=root->FirstChildElement("Entities");
    
        std::string entitiesCount=entities->Attribute("count");
        int count=std::stoi(entitiesCount);
        
        return count;
        
    }

    void U4DSceneConfig::addNewEntity(std::string uName, std::string uRefName){
        
        U4DSerializer *serializer=U4DSerializer::sharedInstance();
        
        tinyxml2::XMLElement *entities=root->FirstChildElement("Entities");
    
        std::string entitiesCount=entities->Attribute("count");
        int count=std::stoi(entitiesCount);
        
        tinyxml2::XMLElement* entity = serializer->xmlDoc.NewElement("entity");
        entity->SetAttribute("name", uName.c_str());
        entity->SetAttribute("refName", uRefName.c_str());
        entity->SetText("\n");
        entities->InsertEndChild(entity);
        
        //properties
        tinyxml2::XMLElement* properties=serializer->xmlDoc.NewElement("Properties");
        properties->SetText("\n");
        entity->InsertEndChild(properties);
        
        //space
        tinyxml2::XMLElement* space=serializer->xmlDoc.NewElement("Space");
        space->SetText("\n");
        properties->InsertEndChild(space);
        
        {
            tinyxml2::XMLElement* position=serializer->xmlDoc.NewElement("position");
            position->SetText("0.0 0.0 0.0");
            space->InsertEndChild(position);
            
            tinyxml2::XMLElement* orientation=serializer->xmlDoc.NewElement("orientation");
            orientation->SetText("0.0 0.0 0.0");
            space->InsertEndChild(orientation);
        }
        
        //kinetics
        tinyxml2::XMLElement* kinetics=serializer->xmlDoc.NewElement("Kinetics");
        kinetics->SetAttribute("enabled", false);
        kinetics->SetText("\n");
        properties->InsertEndChild(kinetics);
        
        //kinetics children
            {
                tinyxml2::XMLElement* gravity=serializer->xmlDoc.NewElement("gravity");
                gravity->SetText("0.0 -10.0 0.0");
                kinetics->InsertEndChild(gravity);
                
                tinyxml2::XMLElement* mass=serializer->xmlDoc.NewElement("mass");
                mass->SetText("1.0");
                kinetics->InsertEndChild(mass);
            }
            
        
        //collision
        tinyxml2::XMLElement* collision=serializer->xmlDoc.NewElement("Collision");
        collision->SetAttribute("enabled", false);
        collision->SetText("\n");
        properties->InsertEndChild(collision);
        
        //collision children
        
            {
                tinyxml2::XMLElement* coefRestitution=serializer->xmlDoc.NewElement("coefRestitution");
                coefRestitution->SetText("0.8");
                collision->InsertEndChild(coefRestitution);

                tinyxml2::XMLElement* platform=serializer->xmlDoc.NewElement("platform");
                platform->SetText("0");
                collision->InsertEndChild(platform);
                
                tinyxml2::XMLElement* sensor=serializer->xmlDoc.NewElement("sensor");
                sensor->SetText("0");
                collision->InsertEndChild(sensor);

                tinyxml2::XMLElement* tag=serializer->xmlDoc.NewElement("tag");
                tag->SetText("tag");
                collision->InsertEndChild(tag);
                
            }
        
        //animation
        tinyxml2::XMLElement* animation=serializer->xmlDoc.NewElement("Animation");
        animation->SetText("\n");
        properties->InsertEndChild(animation);
        
        //update the count of entities
        entities->SetAttribute("count", ++count);
        
    }

    tinyxml2::XMLElement *U4DSceneConfig::getEntityElement(std::string uName, std::string uSystem, std::string uComponent){
        
        tinyxml2::XMLElement *nullElement=nullptr;
        
        tinyxml2::XMLElement *entities=root->FirstChildElement("Entities");
        
        for (tinyxml2::XMLElement *child=entities->FirstChildElement("entity"); child!=NULL; child=child->NextSiblingElement("entity")) {
         
            std::string entityName=child->Attribute("name");
            
            if (entityName.compare(uName)==0) {
            
                tinyxml2::XMLElement *properties=child->FirstChildElement("Properties");
                
                tinyxml2::XMLElement *element=properties->FirstChildElement(uSystem.c_str())->FirstChildElement(uComponent.c_str());
                    
                if(element!=nullptr){
                    return element;
                    
                }
            }
        
        }
        
        return nullElement;
        
    }

    bool U4DSceneConfig::getEntityBehavior(std::string uName, std::string uSystem){
        
        tinyxml2::XMLElement *entities=root->FirstChildElement("Entities");
        
        for (tinyxml2::XMLElement *child=entities->FirstChildElement("entity"); child!=NULL; child=child->NextSiblingElement("entity")) {
         
            std::string entityName=child->Attribute("name");
            
            if (entityName.compare(uName)==0) {
            
                tinyxml2::XMLElement *properties=child->FirstChildElement("Properties");
                
                tinyxml2::XMLElement *element=properties->FirstChildElement(uSystem.c_str());
                    
                if(element!=nullptr){
                    std::string valueString=element->Attribute("enabled");
                    bool value=false;
                    std::istringstream(valueString) >> value;
                    
                    return value;
                }
            }
        
        }
        
        return false;
    }

    bool U4DSceneConfig::getEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, char *uData, int uSize){
        
        tinyxml2::XMLElement *element=getEntityElement(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            std::string valueString=element->GetText();
            // copying the contents of the
            // string to char array
            strcpy(uData, valueString.c_str());
         
            return true;
        }
        
        return false;
        
    }

    bool U4DSceneConfig::getEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, std::vector<float> *uData){
        
        tinyxml2::XMLElement *element=getEntityElement(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            std::string valueString=element->GetText();

            stringToFloat(valueString,uData);
            
            return true;
        }
        
        return false;
        
    }

    bool U4DSceneConfig::getEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, float *uData){
        
        
        tinyxml2::XMLElement *element=getEntityElement(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            std::string valueString=element->GetText();

            *uData=std::stof(valueString);
            
            return true;
        }
        
        return false;
        
    }

    bool U4DSceneConfig::getEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, float *uData,int uSize){
        
        tinyxml2::XMLElement *element=getEntityElement(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            std::string valueString=element->GetText();

            stringToFloat(valueString,uData,uSize);
            
            return true;
        }
        
        return false;
        
    }

    bool U4DSceneConfig::getEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, bool &uValue){
        
        tinyxml2::XMLElement *element=getEntityElement(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            
            std::string valueString=element->GetText();

            std::istringstream(valueString) >> uValue;
            
            return true;
        }
        
        return false;
    }
    
    void U4DSceneConfig::setEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, bool uValue){
        
        tinyxml2::XMLElement *element=getEntityElement(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            
            element->SetText(uValue);
            
            
        }
        

    }

    void U4DSceneConfig::setEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, char *uData, int uSize){
        
        tinyxml2::XMLElement *element=getEntityElement(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            
            std::string value="";
            for (int i = 0; i < uSize; i++) {
                value = value + uData[i];
                }
            element->SetText(value.c_str());
            
        }
        
        
    }

    void U4DSceneConfig::setEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, float *uData,int uSize){
        
        tinyxml2::XMLElement *element=getEntityElement(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            
            std::string value;
            for (int i=0; i<uSize; i++) {
                
                value+=std::to_string(uData[i]);
                value+=" ";
            }
            element->SetText(value.c_str());
            
            
        }
        
    }

    void U4DSceneConfig::setEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, std::vector<float> uData){
        
        tinyxml2::XMLElement *element=getEntityElement(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            
            std::string value;
            for (int i=0; i<uData.size(); i++) {
                
                value+=std::to_string(uData.at(i));
                value+=" ";
            }
            element->SetText(value.c_str());
            
            
        }
        
    }

    void U4DSceneConfig::setEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, float uValue){
        
        tinyxml2::XMLElement *element=getEntityElement(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            
            std::string value=std::to_string(uValue);
            element->SetText(value.c_str());
            
        }
        
    }

    void U4DSceneConfig::setEntityBehavior(std::string uName, std::string uSystem, bool uValue){
        
        tinyxml2::XMLElement *entities=root->FirstChildElement("Entities");
        
        for (tinyxml2::XMLElement *child=entities->FirstChildElement("entity"); child!=NULL; child=child->NextSiblingElement("entity")) {
         
            std::string entityName=child->Attribute("name");
            
            if (entityName.compare(uName)==0) {
            
                tinyxml2::XMLElement *properties=child->FirstChildElement("Properties");
                
                tinyxml2::XMLElement *element=properties->FirstChildElement(uSystem.c_str());
                    
                if(element!=nullptr){
                    element->SetAttribute("enabled", uValue);
                }
            }
        
        }
        
    }

    tinyxml2::XMLElement *U4DSceneConfig::getSceneProps(std::string uName, std::string uSystem, std::string uComponent){
        
        tinyxml2::XMLElement *nullElement=nullptr;
        
        tinyxml2::XMLElement *scene=root->FirstChildElement(uSystem.c_str());
        
        tinyxml2::XMLElement *entity=scene->FirstChildElement(uName.c_str());
        
        tinyxml2::XMLElement *element=entity->FirstChildElement(uComponent.c_str());
        
        if(element!=nullptr){
            return element;
            
        }
        
        return nullElement;
        
    }

    void U4DSceneConfig::setScenePropsBehavior(std::string uName, std::string uSystem, std::string uComponent, float *uData,int uSize){
        
        tinyxml2::XMLElement *element=getSceneProps(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            
            std::string value;
            for (int i=0; i<uSize; i++) {
                
                value+=std::to_string(uData[i]);
                value+=" ";
            }
            element->SetText(value.c_str());
            
            
        }
        
    }

    bool U4DSceneConfig::getScenePropsBehavior(std::string uName, std::string uSystem, std::string uComponent, float *uData,int uSize){
        
        tinyxml2::XMLElement *element=getSceneProps(uName, uSystem, uComponent);
        
        if(element!=nullptr){
            std::string valueString=element->GetText();

            stringToFloat(valueString,uData,uSize);
            
            return true;
        }
        
        return false;
        
    }

    tinyxml2::XMLElement *U4DSceneConfig::getEntitySystem(std::string uName, std::string uSystem){
        
        tinyxml2::XMLElement *nullSystem=nullptr;
        
        tinyxml2::XMLElement *entities=root->FirstChildElement("Entities");
        
        for (tinyxml2::XMLElement *child=entities->FirstChildElement("entity"); child!=NULL; child=child->NextSiblingElement("entity")) {
         
            std::string entityName=child->Attribute("name");
            
            if (entityName.compare(uName)==0) {
            
                tinyxml2::XMLElement *properties=child->FirstChildElement("Properties");
                
                tinyxml2::XMLElement *system=properties->FirstChildElement(uSystem.c_str());
                    
                if(system!=nullptr){
                    return system;
                    
                }
            }
        
        }
        
        return nullSystem;
        
        
    }

    bool U4DSceneConfig::addAnimationElement(std::string uName, std::string uElementName){
        
        U4DSerializer *serializer=U4DSerializer::sharedInstance();
        tinyxml2::XMLElement *system=getEntitySystem(uName, "Animation");
        
        if(system!=nullptr){
            
            //check if element exist
            for (tinyxml2::XMLElement *child=system->FirstChildElement("animation"); child!=NULL; child=child->NextSiblingElement("animation")) {
                
                std::string elementName=child->Attribute("name");
                
                if (elementName.compare(uElementName)==0) {
                    
                    return false;
                }
                
            }
            
            tinyxml2::XMLElement* animation=serializer->xmlDoc.NewElement("animation");
            animation->SetAttribute("name", uElementName.c_str());
            animation->SetText(" ");
            system->InsertEndChild(animation);
            
            return true;
        }
        
        
        return false;
        
    }

    std::vector<std::string> U4DSceneConfig::getAllAnimationNames(std::string uName){
        
        std::vector<std::string> elementContainer;
        
        tinyxml2::XMLElement *system=getEntitySystem(uName, "Animation");
        
        if(system!=nullptr){
            
            for (tinyxml2::XMLElement *child=system->FirstChildElement("animation"); child!=NULL; child=child->NextSiblingElement("animation")) {
                
                elementContainer.push_back(child->Attribute("name"));
                
            }
        }
        
        return elementContainer;
    }

    bool U4DSceneConfig::removeAnimationElement(std::string uName, std::string uElementName){
        
        U4DSerializer *serializer=U4DSerializer::sharedInstance();
        tinyxml2::XMLElement *system=getEntitySystem(uName, "Animation");
        
        if(system!=nullptr){
            
            for (tinyxml2::XMLElement *child=system->FirstChildElement("animation"); child!=NULL; child=child->NextSiblingElement("animation")) {
                
                std::string elementName=child->Attribute("name");
                
                if (elementName.compare(uElementName)==0) {
                    serializer->xmlDoc.DeleteNode(child);
                    return true;
                }
                
            }
        }
        
        return false;
        
    }

    void U4DSceneConfig::stringToFloat(std::string uStringData,std::vector<float> *uFloatData){
            
            std::stringstream stringToParse(uStringData);
            
            std::string outString;
            
            while (getline(stringToParse, outString, ' ')) {
                
                std::istringstream iss(outString);
                
                float c=stof(outString);
                
                uFloatData->push_back(c);
                
            }
            
        }

    void U4DSceneConfig::stringToFloat(std::string uStringData,float *uFloatData, int uSize){
        
        std::stringstream stringToParse(uStringData);
        
        std::string outString;
        int count=0;
        
        while (getline(stringToParse, outString, ' ') && count<uSize) {
            
            std::istringstream iss(outString);
            
            float c=stof(outString);
            
            uFloatData[count]=c;
            
            count++;
        }
    }

    void U4DSceneConfig::stringToInt(std::string uStringData,std::vector<int> *uIntData){
        
        std::stringstream stringToParse(uStringData);
        
        std::string outString;
        
        while (getline(stringToParse, outString, ' ')) {
            
            std::istringstream iss(outString);
            
            int c=stoi(outString);
            
            uIntData->push_back(c);
            
        }
        
    }

}
