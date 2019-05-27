//
//  U4DNavMeshLoader.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/20/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DNavMeshLoader.h"
#include <stdio.h>
#include <string.h>
#include <vector>
#include <sstream>
#include "U4DLogger.h"
#include "U4DDirector.h"
#include "U4DPoint3n.h"

namespace U4DEngine {
    
    U4DNavMeshLoader::U4DNavMeshLoader(){
        
    }
    
    U4DNavMeshLoader::~U4DNavMeshLoader(){
        
    }
    
    U4DNavMeshLoader* U4DNavMeshLoader::instance=0;
    
    U4DNavMeshLoader* U4DNavMeshLoader::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DNavMeshLoader();
        }
        
        return instance;
    }
    
    
    bool U4DNavMeshLoader::loadDigitalAssetFile(const char* uFile){
        
        //if file exists, simply return. no need to load the file again
        std::string uStringFile(uFile);
        if (currentLoadedFile.compare(uStringFile)==0) {
            
            return true;
            
        }
        
        bool loadOk=doc.LoadFile(uFile);
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if (!loadOk) {
            
            logger->log("Success: Navigation Mesh File %s succesfully Loaded.",uFile);
            
            currentLoadedFile=uFile;
            
            loadOk=true;
            
        }else{
            
            logger->log("Error: Couldn't load the Navigation Mesh File, No file %s exist.",uFile);
            
            currentLoadedFile.clear();
            
            loadOk=false;
        }
        
        return loadOk;
    }
    
    
    bool U4DNavMeshLoader::loadNavMesh(U4DNavMesh *uNavMesh, std::string uNavMeshName){
        
        tinyxml2::XMLNode *root=doc.FirstChildElement("UntoldEngine");
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        bool modelExist=false;
        
        //Get Mesh ID
        tinyxml2::XMLElement *node=root->FirstChildElement("asset")->FirstChildElement("navigation_mesh");
        
        if (node!=NULL) {
            
            for (tinyxml2::XMLElement *child=node->FirstChildElement("nav_mesh"); child!=NULL; child=child->NextSiblingElement("nav_mesh")) {
                
                std::string meshName=child->Attribute("name");
                
                //check for the nav mesh exists
                if (meshName.compare(uNavMeshName)==0) {
                    
                    //inform that the model does exist
                    modelExist=true;
                    
                    for (tinyxml2::XMLElement *grandChild=child->FirstChildElement("node"); grandChild!=NULL; grandChild=grandChild->NextSiblingElement("node")) {
                        
                        std::string navMeshIndex=grandChild->Attribute("index");
                        tinyxml2::XMLElement *nodeLocation=grandChild->FirstChildElement("node_location");
                        tinyxml2::XMLElement *nodeNeighbours=grandChild->FirstChildElement("node_neighbours");
                        
                        U4DNavMeshNode navMeshNode;
                        
                        //load the node index
                        loadNavMeshNodeIndex(navMeshNode,navMeshIndex);
                        
                        //load the node location
                        if (nodeLocation!=NULL) {
                            std::string data=nodeLocation->GetText();
                            loadNavMeshNodeLocation(navMeshNode,data);
                        }
                        
                        //load the node neighbours
                        if (nodeNeighbours!=NULL) {
                            std::string data=nodeNeighbours->GetText();
                            loadNavMeshNodeNeighbours(navMeshNode,data);
                        }
                        
                        //add the node mesh into the nav mesh vector
                        uNavMesh->navMeshNodeContainer.push_back(navMeshNode);
                        
                    }
                    
                    
                
                }
                
            }
            
            
        }
        
        if (modelExist) {
            
            logger->log("Success: The Navigation Mesh %s has been loaded into the engine.",uNavMeshName.c_str());
            
            return true;
        }
        
        logger->log("Error: No Navigation Mesh with name %s exist.",uNavMeshName.c_str());
        
        return false;
        
    }
    
    void U4DNavMeshLoader::loadNavMeshNodeIndex(U4DNavMeshNode &uNavMeshNode, std::string uStringData){
        
        std::vector<int> tempVector;
        
        stringToInt(uStringData, &tempVector);
        
        if (tempVector.size()>0) {
            
            uNavMeshNode.index=tempVector.at(0);
            
        }
        
    }
    
    void U4DNavMeshLoader::loadNavMeshNodeLocation(U4DNavMeshNode &uNavMeshNode, std::string uStringData){
        
        std::vector<float> tempVector;
        
        stringToFloat(uStringData, &tempVector);
        
        for (int i=0; i<tempVector.size();) {
            
            float x=tempVector.at(i);
            
            float y=tempVector.at(i+1);
            
            float z=tempVector.at(i+2);
            
            U4DPoint3n uLocation(x,y,z);
            
            uNavMeshNode.position=uLocation;
            
            i=i+3;
            
        }
        
    }
    
    void U4DNavMeshLoader::loadNavMeshNodeNeighbours(U4DNavMeshNode &uNavMeshNode, std::string uStringData){
        
        std::vector<int> tempVector;
        
        stringToInt(uStringData, &tempVector);
        
        for(auto n:tempVector){
        
            uNavMeshNode.neighborsIndex.push_back(n);
            
        }
        
    }
    
    
    void U4DNavMeshLoader::stringToFloat(std::string uStringData,std::vector<float> *uFloatData){
        
        std::stringstream stringToParse(uStringData);
        
        std::string outString;
        
        while (getline(stringToParse, outString, ' ')) {
            
            std::istringstream iss(outString);
            
            float c=stof(outString);
            
            uFloatData->push_back(c);
            
        }
        
    }
    
    void U4DNavMeshLoader::stringToInt(std::string uStringData,std::vector<int> *uIntData){
        
        std::stringstream stringToParse(uStringData);
        
        std::string outString;
        
        while (getline(stringToParse, outString, ' ')) {
            
            std::istringstream iss(outString);
            
            int c=stoi(outString);
            
            uIntData->push_back(c);
            
        }
        
    }
    
}
