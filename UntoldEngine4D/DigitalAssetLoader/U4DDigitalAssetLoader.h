//
//  U4DDigitalAssetLoader.h
//  ColladaLoader
//
//  Created by Harold Serrano on 5/28/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DDigitalAssetLoader__
#define __UntoldEngine__U4DDigitalAssetLoader__

#include <iostream>
#include <vector>
#include "tinyxml2.h"


namespace U4DEngine {
    
class U4DEntity;
class U4DModel;
class U4DMatrix4n;
class U4DVector3n;
class U4DVector2n;
class U4DVector4n;
class U4DIndex;
class U4DDualQuaternion;
class U4DQuaternion;
class U4DLights;
class U4DAnimation;

}

namespace U4DEngine {
    
    /**
     @brief The U4DDigitalAssetLoader class is in charge of importing 3D model assets.
     */
    class U4DDigitalAssetLoader{

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
         @brief Constructor for the digital asset loader
         */
        U4DDigitalAssetLoader();
        
        /**
         @brief Destructor for the digital asset loader
         */
        ~U4DDigitalAssetLoader();

        
    public:
        
        /**
         @brief  Instance for the digital asset loader Singleton
         */
        static U4DDigitalAssetLoader* instance;
        
        /**
         @brief  Shared Instance for the digital asset loader Singleton
         */
        static U4DDigitalAssetLoader* sharedInstance();
        
        /**
         @brief Method which imports the asset file containing 3D asset information
         
         @param uFile Name of the file containing the 3D asset information
         
         @return Returs true if the file was successfully loaded into the engine
         */
        bool loadDigitalAssetFile(const char* uFile);
        
        /**
         @brief Method which loads all 3D asset information into the 3D model entity
         
         @param uModel  3D model entity
         @param uMeshID Name of the 3D model given by the modeling software
         
         @return Returns true if the 3D assets were loaded successfully into the 3D entity
         */
        bool loadAssetToMesh(U4DModel *uModel,std::string uMeshID);
        
        /**
         @brief Method which loads the Entity matrix space-Orientation and translation
         
         @param uModel      3D model entity
         @param uStringData string data containing the matrix space information
         */
        void loadEntityMatrixSpace(U4DEntity *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model vertices
         
         @param uModel      3D model entity
         @param uStringData string data containing the vertices information
         */
        void loadVerticesData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model Normal vertices
         
         @param uModel      3D model entity
         @param uStringData string data containing the Normal vertices
         */
        void loadNormalData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model uv coordinates
         
         @param uModel      3D model entity
         @param uStringData string data containing the uv coordinates
         */
        void loadUVData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model PRE-Hull data. That is, data ready to be used to compute the Convex Hull of the model
         
         @param uModel      3D model entity
         @param uStringData string data containing the pre-hull data
         */
        void loadPreHullData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model indices data used by opengl to properly render the model
         
         @param uModel      3D model entity
         @param uStringData string data containing the indices data
         */
        void loadIndexData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the index information for each material used by the 3D model entity
         
         @param uModel      3D model entity
         @param uStringData index information for each material used by the 3D entity
         */
        void loadMaterialIndexData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model diffuse material color information
         
         @param uModel      3D model entity
         @param uStringData string data containing the diffuse material color information
         */
        void loadDiffuseColorData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model specular material color information
         
         @param uModel      3D model entity
         @param uStringData string data containing the specular material color information
         */
        void loadSpecularColorsData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model diffuse material intensity information
         
         @param uModel      3D model entity
         @param uStringData string data containing the diffuse intensity information
         */
        void loadDiffuseIntensityData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model specular material intensity information
         
         @param uModel      3D model entity
         @param uStringData string data containing the specular intensity information
         */
        void loadSpecularIntensityData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model specular material shininess information
         
         @param uModel      3D model entity
         @param uStringData string data containing the specular shininess information
         */
        void loadSpecularHardnessData(U4DModel *uModel,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model dimension information
         
         @param uModel      3D model entity
         @param uStringData string data containing the dimension of the 3D model
         */
        void loadDimensionDataToBody(U4DModel *uModel,std::string uStringData);
        
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
         @brief Method which loads the 3D model armature bone weights
         
         @param uVertexWeights 3D model bone weight container
         @param uStringData    string data containing the bone weight data
         */
        void loadVertexBoneWeightsToBody(std::vector<float> &uVertexWeights,std::string uStringData);
        
        /**
         @brief Method which loads the 3D model animation information
         
         @param uAnimation     animation information to load
         @param uAnimationName Name of the animation to load
         
         @return Returns true if the animation was successfully loaded into the 3D model
         */
        bool loadAnimationToMesh(U4DAnimation *uAnimation,std::string uAnimationName);
        
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

#endif /* defined(__UntoldEngine__U4DDigitalAssetLoader__) */
