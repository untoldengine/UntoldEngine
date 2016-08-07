//
//  U4DDigitalAssetLoader.h
//  ColladaLoader
//
//  Created by Harold Serrano on 5/28/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
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
    
    class U4DDigitalAssetLoader{

    private:
        
        tinyxml2::XMLDocument doc;
        
    protected:
        
        U4DDigitalAssetLoader();
        
        ~U4DDigitalAssetLoader();

        
    public:
        
        /**
         *  Instance for U4DDigitalAssetLoader Singleton
         */
        static U4DDigitalAssetLoader* instance;
        
        /**
         *  SharedInstance for U4DDigitalAssetLoader Singleton
         */
        static U4DDigitalAssetLoader* sharedInstance();
        
        bool loadDigitalAssetFile(const char* uFile);
        
        bool loadAssetToMesh(U4DModel *uModel,std::string uMeshID);
        
        void getObjectTransformationMatrix(U4DModel *uModel,std::string uMeshID);
        
        void loadEntityMatrixSpace(U4DEntity *uModel,std::string uStringData);
        
        void loadVerticesData(U4DModel *uModel,std::string uStringData);
        
        void loadNormalData(U4DModel *uModel,std::string uStringData);
        
        void loadUVData(U4DModel *uModel,std::string uStringData);
        
        void loadIndexData(U4DModel *uModel,std::string uStringData);
        
        void loadMaterialIndexData(U4DModel *uModel,std::string uStringData);
        
        void loadDiffuseColorData(U4DModel *uModel,std::string uStringData);
        
        void loadSpecularColorsData(U4DModel *uModel,std::string uStringData);
        
        void loadDiffuseIntensityData(U4DModel *uModel,std::string uStringData);
        
        void loadSpecularIntensityData(U4DModel *uModel,std::string uStringData);
        
        void loadSpecularHardnessData(U4DModel *uModel,std::string uStringData);
        
        void loadTangentDataToBody(U4DModel *uModel);
        
        void loadDimensionDataToBody(U4DModel *uModel,std::string uStringData);
        
        void loadMatrixToBody(U4DDualQuaternion &uSpace, std::string uStringData);
        
        void loadVertexBoneWeightsToBody(std::vector<float> &uVertexWeights,std::string uStringData);
        
        void loadAnimationToMesh(U4DAnimation *uAnimation,std::string uAnimationName);
        
        void stringToFloat(std::string uStringData,std::vector<float> *uFloatData);
        
        void stringToInt(std::string uStringData,std::vector<int> *uIntData);
    };

}

#endif /* defined(__UntoldEngine__U4DDigitalAssetLoader__) */
