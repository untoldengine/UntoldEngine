//
//  U4DStaticAction.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DStaticAction__
#define __UntoldEngine__U4DStaticAction__

#include <iostream>
#include "U4DModel.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
    class U4DMesh;
    
}

namespace U4DEngine {
    
    /**
     @brief The ConvexHullProperties structure contains the convex-hull vertices of the 3D static model
     */
    typedef struct{
     
        /**
         @brief Convex-Hull vertices of the 3D static model
         */
        std::vector<U4DVector3n> convexHullVertices;
    
    }ConvexHullProperties;
    
    /**
     @brief The MassProperties structure contains mass properties information of the 3D static model
     */
    typedef struct{
        
        /**
         @brief Mass of 3D model
         */
        float mass=0.0;
        
        /**
         @brief Inertia Tensor type of the static 3D model
         */
        INERTIATENSORTYPE inertiaTensorType;
        
        /**
         @brief Center of mass of the static 3D model
         */
        U4DVector3n centerOfMass;
        
        /**
         @brief Moment of inertia of static 3D model
         */
        U4DMatrix3n momentOfInertiaTensor;
        
        /**
         @brief Inverse moment of inertia of the static 3D model
         */
        U4DMatrix3n inverseMomentOfInertiaTensor;
        
        /**
         @brief Variable stating if the inertia tensor of the 3D static model has been computed
         */
        bool intertiaTensorComputed;
        
    }MassProperties;

    /**
     @brief The ContactManifoldProperties structure contains collision contact manifold of the 3D static model
     */
    typedef struct{
        /**
         @brief Collision contact points
         */
        std::vector<U4DVector3n> contactPoint;
        
        /**
         @brief Collision normal force
         */
        U4DVector3n normalForce;
        
        /**
         @brief Collision normal face direction vector
         */
        U4DVector3n normalFaceDirection;
        
        /**
         @brief Collision Penetration depth
         */
        float penetrationDepth=0.0;
        
    }ContactManifoldProperties;

    /**
     @brief The CollisionProperties structure contains collision information of the 3D static model
     */
    typedef struct{
        /**
         @brief Collision contact manifold properties
         */
        ContactManifoldProperties contactManifoldProperties;
        
        /**
         @brief Variable stating if the 3D static model has collided
         */
        bool collided=false;
        
        /**
         @brief Variable stating if the 3D static model has collided in the broad phase stage
         */
        bool broadPhaseCollided=false;
        
    }CollisionProperties;
    
    /**
     @brief The CollisionFilter structure contains the filtering information of the 3D model
     */
    typedef struct{
        
        /**
         @brief Collision Categories means: I am of type...
         */
        int category=1;
        
        /**
         @brief Collision Masks means: I collide with...
         */
        int mask=1;
        
        /**
         @brief The collision group index, follows the following rule:
         
         -if either fixture has a groupIndex of zero, use the category/mask rules as above
         -if both groupIndex values are non-zero but different, use the category/mask rules as above
         -if both groupIndex values are the same and positive, collide
         -if both groupIndex values are the same and negative, don't collide
         */
        signed int groupIndex=0;
        
    }CollisionFilter;
}


namespace U4DEngine {

    /**
     @ingroup physicsengine
     @brief The U4DStaticAction class represents actions such as collision detections applied to a 3D model entity
     */
    class U4DStaticAction{
        
        private:
        
        
        
        /**
         @brief Variable stating if model can detect collisions
         */
        bool collisionEnabled;
    
        /**
         @brief Object representing the narrow-phase bounding volume
         */
        U4DMesh *convexHullBoundingVolume;
    
        /**
         @brief Object representing the broad-phase bounding volume
         */
        U4DMesh *broadPhaseBoundingVolume;
        
        
        
        /**
         @brief Object representing mass properties of the model
         */
        MassProperties massProperties;
    
        /**
         @brief Object holding collision information of the model
         */
        CollisionProperties collisionProperties;
    
        /**
         @brief Object holding properties of the model convex-hull
         */
        ConvexHullProperties convexHullProperties;
    
        /**
         @brief Coefficient of Restitution for the model
         */
        float coefficientOfRestitution;
    
        /**
         @brief Variable stating if the model should be consider a platform. For example, a model which will serve as a floor or ground in a game should be set to platform. This is important for collision detection.
         */
        bool isPlatform;
        
        /**
         @brief Representing the collision filter specified for the 3D model. It states with which other 3D models it can collide with.
         */
        CollisionFilter collisionFilter;
        
        /**
         @todo Variable stating if the model should be consider a collision sensor. The engine does not compute contact manifolds on collision sensors. It simply determines if a collision occurred or not.
         */
        bool isCollisionSensor;
        
        /**
         @brief vector holding all 3d models the object has collided in the current time step
         */
        std::vector<U4DStaticAction*> collisionList;
        
        /**
         @brief vector holding all 3d models the object has collided (in broad phase) in the current time step
         */
        std::vector<U4DStaticAction*> broadPhaseCollisionList;
        
        /**
         @brief tag used to identify the 3d model during collisions
         */
        std::string collidingTag;
        
        protected:
        
        
        public:

        U4DModel *model;
        
        /**
         @brief Constructor for the class
         */
        U4DStaticAction(U4DModel *uU4DModel);
        
        /**
         @brief Destructor for the class
         */
        ~U4DStaticAction();
        
        /**
         @brief Copy constructor
         */
        U4DStaticAction(const U4DStaticAction& value);

        /**
         @brief Copy constructor
         
         @param value 3D Static model object to copy to
         
         @return Returns a copy of the 3D static model
         */
        U4DStaticAction& operator=(const U4DStaticAction& value);
    
        
        /**
         @brief Method which sets the mass of the model
         
         @param uMass   Mass of the static model
         */
        void initMass(float uMass);
    
        /**
         @brief Method which sets the center of mass of the model
         
         @param uCenterOfMass   Center of mass of the static model
         */
        void initCenterOfMass(U4DVector3n& uCenterOfMass);
        
        /**
         @brief Method which sets the coefficient of restitution of the model
         
         @param uValue  Coefficient of restitution of the static model
         */
        void initCoefficientOfRestitution(float uValue);
        
        /**
         @brief Method which sets the Interta tensor type of the model
         
         @param uInertiaTensorType  Inertia Tensor type. i.e., cubic, spherical or cylindrical
         */
        void initInertiaTensorType(INERTIATENSORTYPE uInertiaTensorType);
        
        /**
         @brief Method which sets the model as a platform
         
         @param uValue  Set to true if the collision detection system should treat this model as a floor/ground
         */
        void initAsPlatform(bool uValue);
        
        //Set Operations
    
        /**
         @brief Methods which sets the visibility of the Narrow-Phase bounding volume
         
         @param uValue The engine will render the narrow-phase bounding volume if set to true
         */
        void setNarrowPhaseBoundingVolumeVisibility(bool uValue);
        
        /**
         @brief Methods which sets the visibility of the Broad-Phase bounding volume
         
         @param uValue The engine will render the broad-phase bounding volume if set to true
         */
        void setBroadPhaseBoundingVolumeVisibility(bool uValue);
        
        //These set operations should be make private
        
        /**
         @brief Method which sets the collision normal face direction
         
         @param uNormalFaceDirection 3D vector representing the normal face direction
         */
        void setCollisionNormalFaceDirection(U4DVector3n& uNormalFaceDirection);
        
        /**
         @brief Method which sets the collision penetration depth
         
         @param uPenetrationDepth Collision penetration depth
         */
        void setCollisionPenetrationDepth(float uPenetrationDepth);
        
        /**
         @brief Method which sets the Normal force
         
         @param uNormalForce 3D vector representing the normal force
         */
        void setNormalForce(U4DVector3n& uNormalForce);
        
        /**
         @brief Method which informs the engine that the model has collided
         
         @param uValue If set to true, the model has collided
         */
        void setModelHasCollided(bool uValue);
        
        /**
         @brief Method which informs the engine that the model has collided in broad phase stage
         
         @param uValue If set to true, the model has collided
         */
        void setModelHasCollidedBroadPhase(bool uValue);
    
        //Behavior operations
    
        /**
         @brief Enables the model to detect collisions
         @details enables the model to collide with other convex objects.
         */
        void enableCollisionBehavior();
        
        /**
         @brief Pauses the ability of the model to detect collisions
         */
        void pauseCollisionBehavior();
        
        /**
         @brief Resumes the ability for the model to detect collisions
         @details informs the collision engine to re-start collision detection with this object.
         */
        void resumeCollisionBehavior();
        
        /**
         @brief Method which returns if the model can detect collisions
         
         @return Returns true if the model can detect collisions
         */
        bool isCollisionBehaviorEnabled();
    
        //Compute operations
        
        /**
         @brief Computes the inertia tensor of the model geometry
         */
        void computeInertiaTensor();
        
        //Update operations
        
        /**
         @brief Method which updates the convex-hull vertices of the model
         */
        void updateConvexHullVertices();
    
        //add operations
   
        /**
         @brief Method which adds collision contact points to a container
         
         @param uContactPoint collision contact points to add to container
         */
        void addCollisionContactPoint(U4DVector3n& uContactPoint);
    
        //clear operations
        
        /**
         @brief Method which clears all convex-hull vertices
         */
        void clearConvexHullVertices();
    
        /**
         @brief Method which clears all collision information
         */
        void clearCollisionInformation();
        
        //Get Operations
        
        /**
         @brief Method which returns the mass of the model
         
         @return Returns the mass of the model
         */
        float getMass()const;
        
        /**
         @brief Method which returns the center of mass of the model
         
         @return Returns the center of mass of the model
         */
        U4DVector3n getCenterOfMass();
        
        /**
         @brief Method which returns the coefficient of restitution of the model
         
         @return Returns the coefficient of restitution of the model
         */
        float getCoefficientOfRestitution();
        
        
        /**
         @brief Method which returns the inertia tensor type of the model
         
         @return Returns the inertia tensor type. i.e., cubic, spherical or cylindrical
         */
        INERTIATENSORTYPE getInertiaTensorType();
        
        /**
         @brief Method which returns if the model should be seens as a platform by the collision detection system
         
         @return Returns true if the model is a platform
         */
        bool getIsPlatform();
    
        /**
         @brief Method which returns a 3x3 matrix representing the moment of inertia tensor
         
         @return Returns a 3x3 matrix representing the moment of inertia tensor
         */
        U4DMatrix3n getMomentOfInertiaTensor();
        
        /**
         @brief Method which returns a 3x3 matrix representing the inverse moment of inertia tensor
         
         @return Returns a 3x3 matrix representing the inverse moment of inertia tensor
         */
        U4DMatrix3n getInverseMomentOfInertiaTensor();
    
        /**
         @brief Method which returns the convex-hull vertices
         
         @return Returns the convex-hull vertices
         */
        std::vector<U4DVector3n>& getConvexHullVertices();
    
        /**
         @brief Method which returns the convex-hull vertices count
         
         @return Return the convex-hull vertices count
         */
        int getConvexHullVerticesCount();
    
        /**
         @brief Method which returns the narrow-phase bounding volume
         
         @return Returns the narrow-phase bounding volume
         */
        U4DMesh* getNarrowPhaseBoundingVolume();
    
        /**
         @brief Method which returns if the engine should render the narrow-phase bounding volume
         
         @return Returns true if the engine should render the narrow-phase bounding volume
         */
        bool getNarrowPhaseBoundingVolumeVisibility();
    
        /**
         @brief Method which returns the broad-phase bounding volume
         
         @return Returns the broad-phase bounding volume
         */
        U4DMesh* getBroadPhaseBoundingVolume();
    
        /**
         @brief Method which returns if the engine should render the broad-phase bounding volume
         
         @return Returns true if the engine should render the broad-phase bounding volume
         */
        bool getBroadPhaseBoundingVolumeVisibility();
    
        /**
         @brief Method which returns a 3D vector representing the Normal force
         
         @return Returns a 3D vector representing the normal force
         */
        U4DVector3n getNormalForce();
    
        /**
         @brief Method which returns the collision contact points
         
         @return Returns the collision contact points
         */
        std::vector<U4DVector3n> getCollisionContactPoints();
    
        /**
         @brief Method which clears all collision contact points
         */
        void clearCollisionContactPoints();
    
        /**
         @brief Method which returns the collision normal face direction vector
         
         @return Returns 3D vector representing the collision normal face direction vector
         */
        U4DVector3n getCollisionNormalFaceDirection();
        
        /**
         @brief Method which returns the collision penetration depth
         
         @return Returns the collision penetration depth
         */
        float getCollisionPenetrationDepth();
    
        /**
         @brief Method which returns true if the model has collided
         
         @return Returns true if the model has collided
         */
        bool getModelHasCollided();
        
        /**
         @brief Method which returns true if the model has collided in Broad Phase stage
         
         @return Returns true if the model has collided
         */
        bool getModelHasCollidedBroadPhase();
        
        /**
         * @brief Sets the filter category for collision
         * @details The filter category refers to "I am of type...". 
         * 
         * @param uFilterCategory filter category
         */
        void setCollisionFilterCategory(int uFilterCategory);

        /**
         * @brief Set the filter mask for collision 
         * @details The filter mask refers to "I collide with types..."
         * 
         * @param uFilterMask filter mask
         */
        void setCollisionFilterMask(int uFilterMask);
        
        /**
         * @brief Sets the group filter for collisions
         * @details If both group index values are the same and positive, then both entities will collide.
         * if both group index values are the same and negative, they the entities do not collide.
         * if either entity has a group index of zero, then the category/mask rule is used.
         * if both entities group index are non-zero but different, the category/mask rule is used.
         * 
         * @param int group index
         */
        void setCollisionFilterGroupIndex(signed int uGroupIndex);
        
        /**
         * @brief Get the collision filter category for the entity
         * @details The filter category refers to "I am of type..."
         * @return filter category
         */
        int getCollisionFilterCategory();
        
        /**
         * @brief Get the collision filter mask for the entity  
         * @details the filter mask refers to "I collide with types of..."
         * @return filter mask
         */
        int getCollisionFilterMask();
        
        /**
         * @brief Get the filter group index    
         * @details If both group index values are the same and positive, then both entities will collide.
         * if both group index values are the same and negative, they the entities do not collide.
         * if either entity has a group index of zero, then the category/mask rule is used.
         * if both entities group index are non-zero but different, the category/mask rule is used.
         * 
         * @return filter group
         */
        signed int getCollisionFilterGroupIndex();
        
        
        
        /**
         * @brief Sets the entity as a collision sensor
         * @details When an entity is set as a sensor, the engine will not compute a collision response for the entity. That is, it will not compute the 
         * resultant velocity and position
         * 
         * @param uValue value 
         */
        void setIsCollisionSensor(bool uValue);
        
        /**
         * @brief Is the entity a collision sensor
         * @details When an entity is set as a sensor, the engine will not compute a collision response for the entity. That is, it will not compute the 
         * resultant velocity and position
         * 
         * @return true if the entity is a collision sensor
         */
        bool getIsCollisionSensor();
        
        /**
         * @brief Add all the 3D models the entity is currently colliding
         * @details The collision list keeps a list of all the 3D entities currently colliding with this entity
         * 
         * @param uModel 3d model currently colliding
         */
        void addToCollisionList(U4DStaticAction *uModel);
        
        /**
         * @brief Add all the 3D models the entity is currently colliding in broad phase collision
         * @details The collision list keeps a list of all the 3D entities currently colliding with this entity
         *
         * @param uModel 3d model currently colliding
         */
        void addToBroadPhaseCollisionList(U4DStaticAction *uModel);
        
        /**
         * @brief Gets a list of all entities currently colliding with the entity
         * @details The collision list keeps a list of all the 3D entities currently colliding with this entity   
         *   
         * @return vector with a list of entities
         */
        std::vector<U4DStaticAction *> getCollisionList();
        
        /**
         * @brief Gets a list of all entities currently colliding (broad phase stage) with the entity
         * @details The collision list keeps a list of all the 3D entities currently colliding with this entity
         *
         * @return vector with a list of entities
         */
        std::vector<U4DStaticAction *> getBroadPhaseCollisionList();
        
        /**
         * @brief Sets a collision tag
         * @details The collision tag can be used to determine exactly who is the entity colliding with
         * 
         * @param uCollidingTag tag name
         */
        void setCollidingTag(std::string uCollidingTag);
        
        /**
         * @brief Gets the collision tag
         * @details The collision tag can be used to determine exactly who is the entity colliding with 
         *  
         * @return tag name
         */
        std::string getCollidingTag();
        
        /**
         * @brief Clears the collision list
         * @details The collision list keeps a list of all the 3D entities currently colliding with this entity
         */
        void clearCollisionList();
        
        /**
         * @brief Clears the collision list
         * @details The collision list keeps a list of all the 3D entities currently colliding with this entity during broad phase stage
         */
        void clearBroadPhaseCollisionList();
        
        /**
         * @brief Clear model buffers for collision
         */
        void clearModelCollisionData();
        
        };
    
}

#endif /* defined(__UntoldEngine__U4DStaticAction__) */
