//
//  U4DPackedDigitalAssetLoader.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPackedDigitalAssetLoader_hpp
#define U4DPackedDigitalAssetLoader_hpp

#include <stdio.h>
#include <vector>
#include <iostream>
#include <fstream> //for file i/o
#include <iomanip>
#include <cstdlib>
#include <string.h>
#include <sstream>

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

    typedef struct {
        std::string name;
        std::string parent;
        std::vector<float> localMatrix;
        std::vector<float> bindPoseMatrix;
        std::vector<float> inversePoseMatrix;
        std::vector<float> restPoseMatrix;
        std::vector<float> vertexWeights;
    }BONES;

    typedef struct{
        int numberOfBones;
        std::vector<float> bindShapeMatrix;
        std::vector<BONES> bones;
    }ARMATURE;

    typedef struct {
        
        std::string name;
        std::vector<float> vertices;
        std::vector<float> normals;
        std::vector<float> uv;
        std::vector<int> index;
        std::vector<float> prehullVertices;
        std::vector<int> materialIndex;
        std::vector<float> diffuseColor;
        std::vector<float> specularColor;
        std::vector<float> diffuseIntensity;
        std::vector<float> specularIntensity;
        std::vector<float> specularHardness;
        size_t textureNameSize;
        std::string textureImage;
        std::vector<float> localMatrix;
        std::vector<float> dimension;
        std::vector<float> meshVertices;
        std::vector<int> meshEdgesIndex;
        std::vector<int> meshFacesIndex;
        ARMATURE armature;
        
    }MODELPACKED;
}

namespace U4DEngine {

class U4DPackedDigitalAssetLoader {
    
    private:
        
        std::vector<MODELPACKED> modelsContainer;
        
    protected:
        
        U4DPackedDigitalAssetLoader();
        
        ~U4DPackedDigitalAssetLoader();
        
    public:
        
        static U4DPackedDigitalAssetLoader* instance;
        
        static U4DPackedDigitalAssetLoader* sharedInstance();
        
        bool loadDigitalAssetBinaryData(std::string filepath);
        
        bool loadAssetToMesh(U4DModel *uModel,std::string uMeshID);
    
        void loadVerticesData(U4DModel *uModel,std::vector<float> uVertices);
    
        void loadNormalData(U4DModel *uModel,std::vector<float> uNormals);
    
        void loadUVData(U4DModel *uModel,std::vector<float> uUV);
    
        void loadIndexData(U4DModel *uModel,std::vector<int> uIndex);
    
        void loadPreHullData(U4DModel *uModel,std::vector<float> uPrehull);
    
        void loadMaterialIndexData(U4DModel *uModel,std::vector<int> uMaterialIndex);
        
        void loadDiffuseColorData(U4DModel *uModel,std::vector<float> uDiffuseColor);
        
        void loadSpecularColorsData(U4DModel *uModel,std::vector<float> uSpecularColor);
        
        void loadDiffuseIntensityData(U4DModel *uModel,std::vector<float> uDiffuseIntensity);
        
        void loadSpecularIntensityData(U4DModel *uModel,std::vector<float> uSpecularIntesity);
        
        void loadSpecularHardnessData(U4DModel *uModel,std::vector<float> uSpecularHardness);
        
        void loadDimensionDataToBody(U4DModel *uModel,std::vector<float> uDimension);
        
        void loadEntityMatrixSpace(U4DEntity *uModel,std::vector<float> uLocalMatrix);
    
        void loadMeshVerticesData(U4DModel *uModel,std::vector<float> uMeshVertices);
        
        void loadMeshEdgesData(U4DModel *uModel,std::vector<int> uMeshEdgesIndex);
        
        void loadMeshFacesData(U4DModel *uModel,std::vector<int> uMeshFacesIndex);
    
        void loadSpaceData(U4DMatrix4n &uMatrix, std::vector<float> uSpaceData);
    
        void loadSpaceData(U4DDualQuaternion &uSpace, std::vector<float> uSpaceData);
        
        void loadVertexBoneWeightsToBody(std::vector<float> &uVertexWeights, std::vector<float> uWeights);
        
};
}
#endif /* U4DPackedDigitalAssetLoader_hpp */
