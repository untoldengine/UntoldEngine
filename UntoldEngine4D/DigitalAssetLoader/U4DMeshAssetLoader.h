//
//  U4DMeshAssetLoader.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMeshAssetLoader_hpp
#define U4DMeshAssetLoader_hpp

#include <stdio.h>
#include <vector>
#include <iostream>
#include <fstream> //for file i/o
#include <iomanip>
#include <cstdlib>
#include <string.h>
#include <sstream>
#include "CommonProtocols.h"

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
class U4DParticleSystem;

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
    }BONESRAW;

    typedef struct{
        int numberOfBones;
        std::vector<float> bindShapeMatrix;
        std::vector<BONESRAW> bones;
    }ARMATURERAW;

    typedef struct{
        
        std::string name;
        std::vector<float> convexHullVertices;
        std::vector<float> convexHullEdges;
        std::vector<float> convexHullFaces;
        
    }CONVEXHULLRAW;

    typedef struct{
        std::string boneName;
        std::vector<float> poseMatrix;
    }ANIMPOSERAW;

    typedef struct{
        float time;
        int boneCount;
        std::vector<ANIMPOSERAW> animPoseMatrix;
    }KEYFRAMERAW;

    typedef struct{
        std::string name;
        float fps;
        int keyframeCount;
        std::vector<float> poseTransform;
        std::vector<KEYFRAMERAW> keyframes;
    }ANIMATIONSRAW;

    typedef struct {
        
        std::string name;
        std::vector<float> vertices;
        std::vector<float> normals;
        std::vector<float> uv;
        std::vector<int> index;
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
        ARMATURERAW armature;
        
    }MODELRAW;

    typedef struct{
        
        std::string name;
        unsigned int width;
        unsigned int height;
        std::vector<unsigned char> image;

    }TEXTURESRAW;

    typedef struct{
        
        std::string name;
        std::vector<float> positionVariance;
        float speed=0.0;
        float speedVariance=0.0;
        float lifeSpan=0.0;
        float angle=0.0;
        float angleVariance=0.0;
        std::vector<float> gravity;
        float radialAcceleration=0.0;
        float tangentialAcceleration=0.0;
        float radialAccelerationVariance=0.0;
        float tangentialAccelerationVariance=0.0;
        std::vector<float> startColor;
        std::vector<float> startColorVariance;
        std::vector<float> finishColor;
        std::vector<float> finishColorVariance;
        int maxParticles=0;
        float startParticleSize=0.0;
        float startParticleSizeVariance=0.0;
        float finishParticleSize=0.0;
        float finishParticleSizeVariance=0.0;
        float duration=0.0;
        float maxRadius=0.0;
        float maxRadiusVariance=0.0;
        float minRadius=0.0;
        float minRadiusVariance=0.0;
        float rotatePerSecond=0.0;
        float rotatePerSecondVariance=0.0;
        int blendFunctionSource=0;
        int blendFunctionDestination=0;
        float rotationStart=0.0;
        float rotationStartVariance=0.0;
        float rotationEnd=0.0;
        float rotationEndVariance=0.0;
        std::string texture;
        
    }PARTICLESRAW;

}

namespace U4DEngine {

/**
@ingroup loader
@brief The U4DMeshAssetLoader class is in charge of importing 3D model assets .
*/
class U4DMeshAssetLoader {
    
    private:
        
        /**
        @brief Container holding all the 3D models in the scene
        */
        std::vector<MODELRAW> modelsContainer;
    
        /**
        @brief Container holding all the 3D animation data
        */
        std::vector<ANIMATIONSRAW> animationsContainer;
    
        /**
        @brief Container holding all the textures used in the scene
        */
        std::vector<TEXTURESRAW> texturesContainer;
    
        /**
        @brief Container holding particle data
        */
        std::vector<PARTICLESRAW> particlesContainer;
    
        /**
        @brief Container holding convex hull data
        */
        std::vector<CONVEXHULLRAW> convexHullContainer;
        
    protected:
        
        /**
        @brief Constructor for the digital asset loader
        */
        U4DMeshAssetLoader();
        
        /**
        @brief Destructor for the digital asset loader
        */
        ~U4DMeshAssetLoader();
        
    public:
        
        /**
        @brief  Instance for the digital asset loader Singleton
        */
        static U4DMeshAssetLoader* instance;
        
        /**
        @brief  Shared Instance for the digital asset loader Singleton
        */
        static U4DMeshAssetLoader* sharedInstance();
        
        /**
        @brief Method which loads all scene asset data into the game
        
        @param uFilepath Name of the binary file containing scene data
        
        @return Returns true if the scene assets were loaded successfully
        */
        bool loadSceneData(std::string uFilepath);
    
        /**
        @brief Method which loads the 3D model animation information
        
        @param uFilepath  Name of the binary file containing animation data
        
        @return Returns true if the animation was successfully loaded
        */
        bool loadAnimationData(std::string uFilepath);
    
        /**
        @brief Method which loads texture data information
        
        @param uFilepath  Name of the binary file containing texture data
        
        @return Returns true if the textures was successfully loaded
        */
        bool loadTextureData(std::string uFilepath);
    
        /**
        @brief Method which loads particle data information
        
        @param uFilepath  Name of the binary file containing particle data
        
        @return Returns true if the particle data was successfully loaded
        */
        bool loadParticleData(std::string uFilepath);
        
        /**
        @brief Method which loads all particle asset information into the particle entity
        
        @param uParticleSystem  particle system
        @param uParticleName Name of the particle given by the particle software
        
        @return Returns true if the particle data entity was loaded successfully into the particle system
        */
        bool loadParticeToParticleSystem(U4DParticleSystem *uParticleSystem, std::string uParticleName);
        
        /**
        @brief Method which loads all 3D asset information into the 3D model entity
        
        @param uModel  3D model entity
        @param uMeshName Name of the 3D model given by the modeling software
        
        @return Returns true if the 3D assets were loaded successfully into the 3D entity
        */
        bool loadAssetToMesh(U4DModel *uModel,std::string uMeshName);
    
        /**
        @brief Method which loads the 3D model animation information
        
        @param uAnimation     animation information to load
        @param uAnimationName Name of the animation to load
        
        @return Returns true if the animation was successfully loaded into the 3D model
        */
        bool loadAnimationToMesh(U4DAnimation *uAnimation,std::string uAnimationName);
    
        CONVEXHULL loadConvexHullForMesh(U4DModel *uModel);
        
        /**
        @brief Method which loads the 3D model vertices
        
        @param uModel      3D model entity
        @param uVertices Container containing the vertices information
        */
        void loadVerticesData(U4DModel *uModel,std::vector<float> uVertices);
    
        /**
        @brief Method which loads the 3D model Normal vertices
        
        @param uModel      3D model entity
        @param uNormals Container containing the Normal vertices
        */
        void loadNormalData(U4DModel *uModel,std::vector<float> uNormals);
    
        /**
        @brief Method which loads the 3D model uv coordinates
        
        @param uModel      3D model entity
        @param uUV Container containing the uv coordinates
        */
        void loadUVData(U4DModel *uModel,std::vector<float> uUV);
    
        /**
        @brief Method which loads the 3D model indices data to properly render the model
        
        @param uModel      3D model entity
        @param uIndex Container containing the indices data
        */
        void loadIndexData(U4DModel *uModel,std::vector<int> uIndex);
    
        /**
        @brief Method which loads the index information for each material used by the 3D model entity
        
        @param uModel      3D model entity
        @param uMaterialIndex index information for each material used by the 3D entity
        */
        void loadMaterialIndexData(U4DModel *uModel,std::vector<int> uMaterialIndex);
        
        /**
        @brief Method which loads the 3D model diffuse material color information
        
        @param uModel      3D model entity
        @param uDiffuseColor Data containing the diffuse material color information
        */
        void loadDiffuseColorData(U4DModel *uModel,std::vector<float> uDiffuseColor);
        
        /**
        @brief Method which loads the 3D model specular material color information
        
        @param uModel      3D model entity
        @param uSpecularColor Data containing the specular material color information
        */
        void loadSpecularColorsData(U4DModel *uModel,std::vector<float> uSpecularColor);
        
        /**
        @brief Method which loads the 3D model diffuse material intensity information
        
        @param uModel      3D model entity
        @param uDiffuseIntensity Data containing the diffuse intensity information
        */
        void loadDiffuseIntensityData(U4DModel *uModel,std::vector<float> uDiffuseIntensity);
        
        /**
        @brief Method which loads the 3D model specular material intensity information
        
        @param uModel      3D model entity
        @param uSpecularIntesity Data containing the specular intensity information
        */
        void loadSpecularIntensityData(U4DModel *uModel,std::vector<float> uSpecularIntesity);
        
        /**
        @brief Method which loads the 3D model specular material shininess information
        
        @param uModel      3D model entity
        @param uSpecularHardness Data containing the specular shininess information
        */
        void loadSpecularHardnessData(U4DModel *uModel,std::vector<float> uSpecularHardness);
        
        /**
        @brief Method which loads the 3D model dimension information
        
        @param uModel      3D model entity
        @param uDimension Data containing the dimension of the 3D model
        */
        void loadDimensionDataToBody(U4DModel *uModel,std::vector<float> uDimension);
        
        /**
        @brief Method which loads the Entity matrix space-Orientation and translation
        
        @param uModel      3D model entity
        @param uLocalMatrix Data containing the matrix space information
        */
        void loadEntityMatrixSpace(U4DEntity *uModel,std::vector<float> uLocalMatrix);
    
        /**
        @brief Method to load Mesh Vertex data. Currently used to create an octree around the character
                
        @param uModel      3D model entity
        @param uMeshVertices Data containing the mesh vertices
         */
        void loadMeshVerticesData(U4DModel *uModel,std::vector<float> uMeshVertices);
        
        /**
        @brief Method to load Mesh Edges index data. Currently used to create an octree around the character
                
        @param uModel      3D model entity
        @param uMeshEdgesIndex Data containing the mesh edges indices
         */
        void loadMeshEdgesData(U4DModel *uModel,std::vector<int> uMeshEdgesIndex);
        
        /**
        @brief Method to load Mesh Faces index data. Currently used to create an octree around the character
                
        @param uModel      3D model entity
        @param uMeshFacesIndex Data containing the mesh faces indices
         */
        void loadMeshFacesData(U4DModel *uModel,std::vector<int> uMeshFacesIndex);
    
        /**
        @brief Method which loads space data-Orientation/translation
        
        @param uMatrix      4x4 matrix object receiving the space data
        @param uSpaceData Data containing space information
        */
        void loadSpaceData(U4DMatrix4n &uMatrix, std::vector<float> uSpaceData);
        
        /**
        @brief Method which loads space data-Orientation/translation
        
        @param uSpace      Dual quaternion object receiving the space data
        @param uSpaceData Data containing space information
        */
        void loadSpaceData(U4DDualQuaternion &uSpace, std::vector<float> uSpaceData);
        
        /**
        @brief Method which loads the 3D model armature bone weights
        
        @param uVertexWeights 3D model bone weight container
        @param uWeights    Data containing the bone weight data
        */
        void loadVertexBoneWeightsToBody(std::vector<float> &uVertexWeights, std::vector<float> uWeights);
        
};
}
#endif /* U4DMeshAssetLoader_hpp */
