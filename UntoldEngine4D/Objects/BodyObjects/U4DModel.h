//
//  U4DModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
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
#include "U4DAnimation.h"
#include "CommonProtocols.h"
#include <MetalKit/MetalKit.h>
#include "U4DRenderManager.h"

namespace U4DEngine {

    /**
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
        
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture);
        
        void setNormalMapTexture(std::string uTexture);
        
        void setEnableNormalMap(bool uValue);
        
        bool getEnableNormalMap();
        
        void setEnableShadow(bool uValue);
        
        bool getEnableShadow();
        
        void setHasNormalMap(bool uValue);
        
        bool getHasNormalMap();
        
        void computeNormalMapTangent();
        
        /**
         @brief Method to inform the engine that the 3D model contains material color information
         
         @param uValue Boolean value (True states that the 3D model contains material color information)
         */
        void setHasMaterial(bool uValue);
        
        /**
         @brief Method to inform the engine that the 3D model contains texture information
         
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
         @todo document this
         */
        U4DDualQuaternion getBoneAnimationSpace(std::string uName);
        
        /**
         @brief set if the model should be rendered or not depending if it lies within frustum
         */
        
        void setModelVisibility(bool uValue);
    };
    
}


#endif /* defined(__UntoldEngine__U4DModel__) */
