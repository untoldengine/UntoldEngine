//
//  U4DModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DModel__
#define __UntoldEngine__U4DModel__

#include <iostream>
#include "U4DVisibleEntity.h"
#include "U4DMatrix3n.h"
#include "U4DVertexData.h"
#include "U4DMaterialData.h"
#include "U4DTextureData.h"
#include "U4DArmatureData.h"
#include "U4DPolygonData.h"
#include "U4DAnimation.h"
#include "CommonProtocols.h"
#include <MetalKit/MetalKit.h>
#include "U4DRenderEntity.h"

namespace U4DEngine {
    
    class U4DEntityManager;
    class U4DBoundingVolume;
    class U4DMeshOctreeManager;
}

namespace U4DEngine {

    /**
     @ingroup gameobjects
     @brief The U4DModel class represents a 3D model entity
     */
    class U4DModel:public U4DVisibleEntity{
        
    private:
       
        /**
         @brief Variable which contains information if the 3D model has material color
         */
        bool hasMaterial;
        
        /**
         @brief Variable which contains information if the 3D model has textures
         */
        bool hasTexture;
        
        /**
         @brief Variable which contains information if the 3D model has animation
         */
        bool hasAnimation;
        
        /**
         @brief Variable which contains information if the 3D model has an armature
         */
        bool hasArmature;
        
        bool hasNormalMap;
        
        bool enableNormalMap;
        
        
        bool enableTexture;
        
        /**
         @brief Variable stating the visibility of the culling-phase bounding volume. If set to true, the engine will render the narrow-phase volume
         */
        bool cullingPhaseBoundingVolumeVisibility;
        
        /**
         @brief Object representing the visibility bounding volume for frustum culling
         */
        U4DBoundingVolume *cullingPhaseBoundingVolume;
        
        std::vector<U4DVector4n> shaderParameterContainer;
        
        /**
         @brief Object representing the mesh octree manager
         */
        U4DMeshOctreeManager *meshOctreeManager;
        
    protected:
        
    public:
        
        /**
         @brief Object which contains attribute data such as vertices, normals, uv-coordinates, bone indices, bone weights, etc
         */
        U4DVertexData bodyCoordinates;
        
        /**
         @brief Object which contains material color information
         */
        U4DMaterialData materialInformation;
        
        /**
         @brief Object which contains texture information
         */
        U4DTextureData textureInformation;
        
        /**
         @brief Pointer to an armature object representing an armature manager
         */
        U4DArmatureData *armatureManager;
        
        /**
         @brief Object with polygon (vertices, edges and faces) information
         */
        U4DPolygonData polygonInformation;
        
        /**
         @brief Container holding armature bone matrix data
         */
        std::vector<U4DMatrix4n> armatureBoneMatrix;
        
        /**
         @brief Constructor for the class
         */
        U4DModel();
        
        /**
         @brief Destructor for the class
         */
        ~U4DModel();
        
        /**
         @brief Copy constructor for the class
         */
        U4DModel(const U4DModel& value);

        /**
         @brief Copy constructor for the class
         
         @param value 3D model entity to copy to
         
         @return Returns a copy of the 3D model
         */
        U4DModel& operator=(const U4DModel& value);
        
        /**
         @brief Method which updates the state of the 3D model
         
         @param dt Time-step value
         */
        virtual void update(double dt){};
        
        /**
         @todo document this
         */
        void updateAllUniforms();
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix, any rendering flags, bones and shadows properties. It encodes the pipeline, buffers and issues the draw command
         *
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         @brief returns the rest pose of the bone. Note, an armature must be present
         
         @param uBoneName name of the bone
         @param uBoneRestPoseMatrix bone rest pose matrix
         @return returns true if the rootbone rest pose exists. The uBoneRestPoseMatrix will contain the bone rest pose
         */
        bool getBoneRestPose(std::string uBoneName, U4DMatrix4n &uBoneRestPoseMatrix);

        /**
         @brief returns the animation pose of the bone. Note, an armature must be present and an animation must currently be playing.
         
         @param uBoneName name of the bone
         @param uAnimation current animation being played
         @param uBoneAnimationPoseMatrix bone animation pose matrix
         
         @return returns true along with the animation pose space of the bone. The uBoneAnimationPoseMatrix will contain the animation pose matrix.
         */
        bool getBoneAnimationPose(std::string uBoneName, U4DAnimation *uAnimation, U4DMatrix4n &uBoneAnimationPoseMatrix);
        
        /**
        @brief Method which loads Digital Asset data into the game character. Note, the mesh asset binary data must be loaded before calling this method.
        @param uModelName   Name of the model in the Digital Asset File
       
        @return Returns true if the digital asset data was successfully loaded
        */
        bool loadModel(const char* uModelName);
        
        /**
        @brief Method which loads Animation data into the game character. Note, the animation asset binary data must be loaded before calling this method.
    
        @param uAnimation     Pointer to the animation
        @param uAnimationName Name of the animation
        
        @return Returns true if the animation was successfully loaded
        */
        bool loadAnimationToModel(U4DAnimation *uAnimation, const char* uAnimationName);
        
        /**
         @brief self load 3d model into the visibility manager

         @param uEntityManager pointer to the entity manager
         */
        void loadIntoVisibilityManager(U4DEntityManager *uEntityManager);
        
        /**
         * @brief Get the 3D dimensions
         * @details Gets the widht, length and depth dimensions of the 3D entity
         * @return vector with the dimensions
         */
        U4DVector3n getModelDimensions();
        
        /**
         @brief sets the Normal Map texture used for the 3d model

         @param uTexture name of the normal map
         */
        void setNormalMapTexture(std::string uTexture);
        
        
        /**
         @brief enable Normal Map rendering

         @param uValue true to enable Normal map rendering.
         */
        void setEnableNormalMap(bool uValue);
        
        
        /**
         @brief gets if Normal Map rendering is enabled

         @return true if Normal map rendering has been enable. False otherwise.
         */
        bool getEnableNormalMap();
        
        
        
        /**
         @brief Informs the engine that the 3d model contains Normal Map texture

         @param uValue true states that the 3d model contains a normal map
         */
        void setHasNormalMap(bool uValue);
        
        
        /**
         @brief returns true if the 3D model has Normal Map texture

         @return True if 3D model has Normal Map texture
         */
        bool getHasNormalMap();
        
        
        /**
         @brief computes the Normal map tangent vectors
         @details the tangent vectors are used to properly shade the normal map texture
         */
        void computeNormalMapTangent();
        
        /**
         @brief Informs the engine that the 3D model contains material color information
         
         @param uValue Boolean value (True states that the 3D model contains material color information)
         */
        void setHasMaterial(bool uValue);
        
        /**
         @brief Informs the engine that the 3D model contains texture information
         
         @param uValue Boolean value (True states that the 3D model contains texture information)
         */
        void setHasTexture(bool uValue);
        
        /**
         @brief Method to inform the engine that the 3D model contains animation information
         
         @param uValue Boolean value (True states that the 3D model contains animation information)
         */
        void setHasAnimation(bool uValue);
        
        /**
         @brief Method to inform the engine that the 3D model contains armature information
         
         @param uValue Boolean value (True states that the 3D model contains armature information)
         */
        void setHasArmature(bool uValue);
        
        /**
         @brief Method which returns true if the 3D model has material color information
         
         @return Returns true if 3D model has material color information
         */
        bool getHasMaterial();
        
        /**
         @brief Method which returns true if the 3D model has texture information
         
         @return Returns true if 3D model has texture information
         */
        bool getHasTexture();
        
        /**
         @brief Method which returns true if the 3D model has animation information
         
         @return Returns true if 3D model has animation information
         */
        bool getHasAnimation();
        
        /**
         @brief Method which returns true if the 3D model has armature information
         
         @return Returns true if 3D model has armature information
         */
        bool getHasArmature();
        
        /**
         @brief Method which returns a 3D vector representing the current view-direction of the 3D model
         
         @return Returns 3D vector representing the view-direction of the 3D model
         */
        U4DVector3n getViewInDirection();
     
        /**
         @brief Method which sets the view-direction of the 3D model
         
         @param uDestinationPoint 3D vector representing the destination point.
         */
        void viewInDirection(U4DVector3n& uDestinationPoint);
        
        /**
         @brief Gets the pose animation space of the bone
         
         @return The pose space animation of the bone
         */
        U4DDualQuaternion getBoneAnimationSpace(std::string uName);
        
        /**
         @brief set if the model should be rendered or not depending if it lies within frustum
         */
        
        void setModelVisibility(bool uValue);
        
        /**
         @brief Method which initialized the boundary volume used for frustum culling
         
         */
        void initCullingBoundingVolume();
        
        /**
         @brief Methods which sets the visibility of the Culling-Phase bounding volume
         
         @param uValue The engine will render the culling-phase bounding volume if set to true
         */
        void setCullingPhaseBoundingVolumeVisibility(bool uValue);
        
        /**
         @brief Method which updates the culling-phase bounding volume space
         */
        void updateCullingPhaseBoundingVolumeSpace();
        
        /**
         @brief Method which returns the culling-phase bounding volume
         
         @return Returns the culling-phase bounding volume
         */
        U4DBoundingVolume* getCullingPhaseBoundingVolume();
        
        /**
         @brief Method which returns if the engine should render the culling-phase bounding volume
         
         @return Returns true if the engine should render the culling-phase bounding volume
         */
        bool getCullingPhaseBoundingVolumeVisibility();
        
        void updateShaderParameterContainer(int uPosition, U4DVector4n &uParamater);
        
        std::vector<U4DVector4n> getModelShaderParameterContainer();
        
        void setTexture0(std::string uTexture0);
        
        void setTexture1(std::string uTexture1);
        
        void setRawImageData(std::vector<unsigned char> uRawImageData);
        
        void setImageWidth(unsigned int uImageWidth);
        
        void setImageHeight(unsigned int uImageHeight);
        
        /**
         * @brief Enables the mesh manager to build an octree
         * @details Builds an octree for the 3D model using AABB boxes
         * @param uSubDivisions The subdivisions used for the octree. 1 subdivision=9 nodes, 2 subdivisions=73 node, 3 subdivisions=585 nodes
         */
        void enableMeshManager(int uSubDivisions);
        
        /**
         @brief gets a pointer to the mesh manager in charge of building an octree
         */
        U4DMeshOctreeManager *getMeshOctreeManager();
        
    };
    
}


#endif /* defined(__UntoldEngine__U4DModel__) */
