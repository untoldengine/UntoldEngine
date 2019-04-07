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
#include "U4DRenderManager.h"

namespace U4DEngine {
    
    class U4DBoundingVolume;
    
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
        
        bool enableShadow;
        
        bool enableTexture;
        
        /**
         @brief Variable stating the visibility of the culling-phase bounding volume. If set to true, the engine will render the narrow-phase volume
         */
        bool cullingPhaseBoundingVolumeVisibility;
        
        /**
         @brief Object representing the visibility bounding volume for frustum culling
         */
        U4DBoundingVolume *cullingPhaseBoundingVolume;
        
        
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
         * @brief Renders the current entity
         * @details Updates the space matrix, any rendering flags, bones and shadows properties. It encodes the pipeline, buffers and issues the draw command
         *
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         * @brief Renders the shadow for a 3D entity
         * @details Updates the shadow space matrix, any rendering flags. It also sends the attributes and space uniforms to the GPU
         *
         * @param uRenderShadowEncoder Metal encoder object for the current entity
         * @param uShadowTexture Texture shadow for the current entity
         */
        void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture);
        
        
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
         @brief Enables shadow rendering on the 3d model

         @param uValue true to enable shadow rendering
         */
        void setEnableShadow(bool uValue);
        
        
        /**
         @brief gets if shadow rendering has been enabled on the 3d model

         @return true if shadow rendering is enabled
         */
        bool getEnableShadow();
        
        
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
        
    };
    
}


#endif /* defined(__UntoldEngine__U4DModel__) */
