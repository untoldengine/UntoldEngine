//
//  U4DNavMeshLoader.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/20/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNavMeshLoader_hpp
#define U4DNavMeshLoader_hpp

#include <stdio.h>
#include <iostream>
#include <vector>
#include "tinyxml2.h"
#include "U4DNavMesh.h"
#include "U4DNavMeshNode.h"

namespace U4DEngine {
    
    /**
     @ingroup artificialintelligence
     @brief The U4DNavMeshLoader class loads the navigation mesh imported from blender
     */
    class U4DNavMeshLoader {
        
    private:
        
        /**
         @brief XML document read by the loader
         */
        tinyxml2::XMLDocument doc;
        
        /**
         @brief Name of the currently imported file
         */
        std::string currentLoadedFile;
        
    protected:
        
        /**
         @brief Constructor for the navigation mesh loader
         */
        U4DNavMeshLoader();
        
        /**
         @brief Destructor for the navigation mesh loader
         */
        ~U4DNavMeshLoader();
        
        
    public:
        
        /**
         @brief  Instance for the navigation mesh loader Singleton
         */
        static U4DNavMeshLoader* instance;
        
        /**
         @brief  Shared Instance for the navigation mesh loader Singleton
         */
        static U4DNavMeshLoader* sharedInstance();
        
        
        /**
         @brief loads the digital asset file representing the nav mesh

         @param uFile name of file
         @return true if the file was loaded
         */
        bool loadDigitalAssetFile(const char* uFile);
        
        
        /**
         @brief loads the nav mesh node data

         @param uNavMesh pointer to the navmesh object. The nav mesh data will be loaded into this object.
         @param uNavMeshName name of nav mesh as specified in blender
         @return true if the data was properly loaded into the navmesh object
         */
        bool loadNavMesh(U4DNavMesh *uNavMesh, std::string uNavMeshName);
        
        
        /**
         @brief loads the nav mesh node indices

         @param uNavMeshNode current nav mesh node object
         @param uStringData data containing the index data
         */
        void loadNavMeshNodeIndex(U4DNavMeshNode &uNavMeshNode, std::string uStringData);
        
        
        /**
         @brief loads the nav mesh node location

         @param uNavMeshNode current nav mesh node object
         @param uStringData data containing the location value
         */
        void loadNavMeshNodeLocation(U4DNavMeshNode &uNavMeshNode, std::string uStringData);
        
        
        /**
         @brief loads the nav mesh node neighbours

         @param uNavMeshNode current nav mesh node object
         @param uStringData data containing the neighbours indices values
         */
        void loadNavMeshNodeNeighbours(U4DNavMeshNode &uNavMeshNode, std::string uStringData);
        
        /**
         @brief Method which converts a string value to float value
         
         @param uStringData string data
         @param uFloatData  float data
         */
        void stringToFloat(std::string uStringData,std::vector<float> *uFloatData);
        
        /**
         @brief Method which converts a string value to int value
         
         @param uStringData string data
         @param uIntData    int data
         */
        void stringToInt(std::string uStringData,std::vector<int> *uIntData);
        
    };
    
}


#endif /* U4DNavMeshLoader_hpp */
