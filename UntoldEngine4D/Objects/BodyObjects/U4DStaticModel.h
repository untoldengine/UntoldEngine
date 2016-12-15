//
//  U4DStaticModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DStaticModel__
#define __UntoldEngine__U4DStaticModel__

#include <iostream>
#include "U4DModel.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
    class U4DBoundingVolume;
    
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
        
    }CollisionProperties;
    
    /**
     @brief Document this
     */
    typedef struct{
        
        int category=1;
        
        int mask=1;
        
        signed int groupIndex=0;
        
    }CollisionFilter;
}


namespace U4DEngine {

    /**
     @brief The U4DStaticModel class represents a 3D static model entity
     */
    class U4DStaticModel:public U4DModel{
        
        private:
        
        /**
         @brief Variable stating if model can detect collisions
         */
        bool collisionEnabled;
        
        /**
         @brief Variable stating the visibility of the broad-phase bounding volume. If set to true, the engine will render the broad-phase volume
         */
        bool broadPhaseBoundingVolumeVisibility;
    
        /**
         @brief Variable stating the visibility of the narrow-phase bounding volume. If set to true, the engine will render the narrow-phase volume
         */
        bool narrowPhaseBoundingVolumeVisibility;
    
        /**
         @brief Object representing the narrow-phase bounding volume
         */
        U4DBoundingVolume *convexHullBoundingVolume;
    
        /**
         @brief Object representing the broad-phase bounding volume
         */
        U4DBoundingVolume *broadPhaseBoundingVolume;
    
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
         @brief document this
         */
        CollisionFilter collisionFilter;
        
        protected:
            
        public:

        /**
         @brief Constructor for the class
         */
        U4DStaticModel();
        
        /**
         @brief Destructor for the class
         */
        ~U4DStaticModel();
        
        /**
         @brief Copy constructor
         */
        U4DStaticModel(const U4DStaticModel& value);

        /**
         @brief Copy constructor
         
         @param value 3D Static model object to copy to
         
         @return Returns a copy of the 3D static model
         */
        U4DStaticModel& operator=(const U4DStaticModel& value);
    
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
    
        //Behavior operations
    
        /**
         @brief Method which enables the model to detect collisions
         */
        void enableCollisionBehavior();
        
        /**
         @brief Method which pauses the ability of the model to detect collisions
         */
        void pauseCollisionBehavior();
        
        /**
         @brief Nethod which resumes the ability for the model to detect collisions
         */
        void resumeCollisionBehavior();
        
        /**
         @brief Method which returns if the model can detect collisions
         
         @return Returns true if the model can detect collisions
         */
        bool isCollisionBehaviorEnabled();
    
        //Compute operations
        
        /**
         @brief Method which computes the inertia tensor of the model geometry
         */
        void computeInertiaTensor();
        
        //Update operations
        
        /**
         @brief Method which updates the convex-hull vertices of the model
         */
        void updateConvexHullVertices();
        
        /**
         @brief Method which updates the narrow-phase bounding volume space
         */
        void updateNarrowPhaseBoundingVolumeSpace();
        
        /**
         @brief Method which updates the broad-phase bounding volume space
         */
        void updateBroadPhaseBoundingVolumeSpace();
    
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
        U4DBoundingVolume* getNarrowPhaseBoundingVolume();
    
        /**
         @brief Method which returns if the engine should render the narrow-phase bounding volume
         
         @return Returns true if the engine should render the narrow-phase bounding volume
         */
        bool getNarrowPhaseBoundingVolumeVisibility();
    
        /**
         @brief Method which returns the broad-phase bounding volume
         
         @return Returns the broad-phase bounding volume
         */
        U4DBoundingVolume* getBroadPhaseBoundingVolume();
    
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
         @brief document this
         */
        void setCollisionFilterCategory(int uFilterCategory);

        /**
         @brief document this-Who can the model collide with
         */
        void setCollisionFilterMask(int uFilterMask);
        
        /**
         @brief document this
         */
        void setCollisionFilterGroupIndex(signed int uGroupIndex);
        
        /**
         @brief document this
         */
        int getCollisionFilterCategory();
        
        /**
         @brief document this
         */
        int getCollisionFilterMask();
        
        /**
         @brief document this
         */
        signed int getCollisionFilterGroupIndex();
        
        
        };
    
}

#endif /* defined(__UntoldEngine__U4DStaticModel__) */
