//
//  ObjectManager.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DEntityManager__
#define __UntoldEngine__U4DEntityManager__

#include <iostream>
#include <vector>
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
    class U4DEntity;
    class U4DWorld;
    class U4DCollisionEngine;
    class U4DVisibleEntity;
    class U4DPhysicsEngine;
    class U4DCollisionEngine;
    class U4DCollisionData;
    class U4DTouchesController;
    class U4DControllerInterface;
    class U4DGravityForceGenerator;
    class U4DDragForceGenerator;
    class U4DIntegrator;
    class U4DDynamicModel;
    class U4DModel;
    class U4DCollisionAlgorithm;
    class U4DManifoldGeneration;
    class U4DCollisionResponse;
    class U4DVector3n;
    class U4DBVHManager;
    class U4DVisibilityManager;
    
}


namespace U4DEngine {
    
    /**
     @ingroup gameobjects
     @brief The U4DEntityManager Class manages the rendering, space update, physics, collision and visibility for all objects in a game
     */
    class U4DEntityManager{

    private:
        
        /**
         @brief pointer to the physics engine
         */
        U4DPhysicsEngine *physicsEngine;
     
        /**
         @brief pointer to the collision engine
         */
        U4DCollisionEngine *collisionEngine;
        
        /**
         @brief pointer to the touch controller
         */
        U4DControllerInterface *touchController;
        
        /**
         @brief pointer to the integration method used in the physics engine
         */
        U4DIntegrator *integratorMethod;
        
        /**
         @brief pointer to the collision algorithm used for collision detection
         */
        U4DCollisionAlgorithm *collisionAlgorithm;
        
        /**
         @brief pointer to the manifold generation algorithm used for collision detection
         */
        U4DManifoldGeneration *manifoldGenerationAlgorithm;
        
        /**
         @brief pointer to the BVH tree manager used in collision detection
         */
        U4DBVHManager *bvhTreeManager;
        
        /**
         @brief pointer to the collision response class used for collision detection
         */
        U4DCollisionResponse *collisionResponse;
        
        /**
         @brief pointer to the visibility manager in charge to evaluate if a 3d model is within the camera frustum
         */
        U4DVisibilityManager *visibilityManager;
        
    public:
        
        /**
         @brief pointer to the root entity. This entity represents the root node in the scenegraph
         */
        U4DEntity *rootEntity;
        
        /**
         @brief class constructor
         */
        U4DEntityManager();
     
        /**
         @brief class destructor
         */
        ~U4DEntityManager();
        
        /**
         @brief copy constructor
         */
        U4DEntityManager(const U4DEntityManager& value){};

        /**
         @brief copy constructor
         */
        U4DEntityManager& operator=(const U4DEntityManager& value){return *this;};
     
        /**
         * @brief Renders the entities in the scenegraph
         * @details It calls the individual render method of each entity in the scenegraph
         *
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLCommandBuffer> uCommandBuffer);
        
        /**
         @brief Updates the state of each entity
         @details It updates the space matrix and calls the physics engine and collision system to evaluate each entity.
         
         @param dt time-step value
         */
        void update(float dt);
        
        
        /**
         @brief determines if the current entity is within the camera frustum
         @details any 3D model outside of the frustum are not rendered
         */
        void determineVisibility();
        
        
        /**
         @brief sets the root entity
         @details the root entity represents the root node in the scenegraph
         @param uRootEntity pointer to the root parent entity
         */
        void setRootEntity(U4DVisibleEntity* uRootEntity);
        
        
        /**
         @brief loads the 3D model into the collision engine

         @param uModel pointer to the 3d model
         */
        void loadIntoCollisionEngine(U4DDynamicModel* uModel);
        
        
        /**
         @brief loads the 3D model into the physics engine

         @param uModel pointer to the 3d model
         @param dt time-step
         */
        void loadIntoPhysicsEngine(U4DDynamicModel* uModel,float dt);
        
        
        /**
         @brief loads the 3d model into the visibility manager
         @details the visibility manager determines if a 3d model is within the camera frustum
         @param uModel pointer to the 3d model
         */
        void loadIntoVisibilityManager(U4DModel* uModel);
        
        /**
         @brief change the current visibility interval. The default is 0.5.
         @details This interval determines how fast the BVH is computed to determine which 3D models are within the camera frustum. The lower this interval, the faster the BVH is computed.
         @param uValue time interval.
         */
        void changeVisibilityInterval(float uValue);
        
    };
    
}


#endif /* defined(__UntoldEngine__U4DEntityManager__) */
