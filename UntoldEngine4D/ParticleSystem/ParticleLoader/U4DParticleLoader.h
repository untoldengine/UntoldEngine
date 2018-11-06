//
//  U4DParticleLoader.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/1/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleLoader_hpp
#define U4DParticleLoader_hpp

#include <stdio.h>

#include <iostream>
#include <vector>
#include "tinyxml2.h"

namespace U4DEngine {
    
    class U4DEntity;
    class U4DMatrix4n;
    class U4DVector3n;
    class U4DVector2n;
    class U4DVector4n;
    class U4DIndex;
    class U4DDualQuaternion;
    class U4DQuaternion;
    class U4DParticleSystem;
    
}

namespace U4DEngine {
    
    /**
     @ingroup loader
     @brief The U4DParticleLoader class is in charge of importing 3D particle assets.
     */
    class U4DParticleLoader{
        
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
         @brief Constructor for the particle system loader
         */
        U4DParticleLoader();
        
        /**
         @brief Destructor for the particle system loader
         */
        ~U4DParticleLoader();
        
        
    public:
        
        /**
         @brief  Instance for the particle system loader Singleton
         */
        static U4DParticleLoader* instance;
        
        /**
         @brief  Shared Instance for the particle system loader Singleton
         */
        static U4DParticleLoader* sharedInstance();
        
        /**
         @brief Method which imports the asset file containing 3D asset information
         
         @param uFile Name of the file containing the 3D asset information
         
         @return Returs true if the file was successfully loaded into the engine
         */
        bool loadDigitalAssetFile(const char* uFile);
        
        /**
         @brief Method which loads all 3D asset information into the 3D model entity
         
         @param uParticleSystem  3D model entity
         @param uMeshID Name of the 3D model given by the modeling software
         
         @return Returns true if the 3D assets were loaded successfully into the 3D entity
         */
        bool loadAssetToMesh(U4DParticleSystem *uParticleSystem,std::string uMeshID);
        
        /**
         @brief Method which loads the Entity matrix space-Orientation and translation
         
         @param uParticleSystem      3D model entity
         @param uStringData string data containing the matrix space information
         */
        void loadEntityMatrixSpace(U4DEntity *uParticleSystem,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model vertices
         
         @param uParticleSystem      3D model entity
         @param uStringData string data containing the vertices information
         */
        void loadVerticesData(U4DParticleSystem *uParticleSystem,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model Normal vertices
         
         @param uParticleSystem      3D model entity
         @param uStringData string data containing the Normal vertices
         */
        void loadNormalData(U4DParticleSystem *uParticleSystem,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model uv coordinates
         
         @param uParticleSystem      3D model entity
         @param uStringData string data containing the uv coordinates
         */
        void loadUVData(U4DParticleSystem *uParticleSystem,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model indices data used by opengl to properly render the model
         
         @param uParticleSystem      3D model entity
         @param uStringData string data containing the indices data
         */
        void loadIndexData(U4DParticleSystem *uParticleSystem,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model dimension information
         
         @param uParticleSystem      3D model entity
         @param uStringData string data containing the dimension of the 3D model
         */
        void loadDimensionDataToBody(U4DParticleSystem *uParticleSystem,std::string uStringData);
        
        /**
         @brief Method which loads space data-Orientation/translation
         
         @param uSpace      Dual quaternion object receiving the space data
         @param uStringData string data containing space information
         */
        void loadSpaceData(U4DDualQuaternion &uSpace, std::string uStringData);
        
        /**
         @brief Method which loads space data-Orientation/translation
         
         @param uSpace      4x4 matrix object receiving the space data
         @param uStringData string data containing space information
         */
        void loadSpaceData(U4DMatrix4n &uMatrix, std::string uStringData);
        
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

#endif /* U4DParticleLoader_hpp */
