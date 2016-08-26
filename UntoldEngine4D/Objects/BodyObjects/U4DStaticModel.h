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
    
    typedef struct{
     
        std::vector<U4DVector3n> convexHullVertices;
    
    }ConvexHullProperties;
    
    typedef struct{
        
        float mass=0.0;
        INERTIATENSORTYPE inertiaTensorType;
        U4DVector3n centerOfMass;
        U4DMatrix3n momentOfInertiaTensor;
        U4DMatrix3n inverseMomentOfInertiaTensor;
        bool intertiaTensorComputed;
        
    }MassProperties;

    typedef struct{
        
        std::vector<U4DVector3n> contactPoint;
        U4DVector3n normalForce;
        U4DVector3n normalFaceDirection;
        float penetrationDepth=0.0;
        
    }ContactManifoldProperties;

    typedef struct{
        
        ContactManifoldProperties contactManifoldProperties;
        bool collided=false; //did the model collided
        
    }CollisionProperties;
}


namespace U4DEngine {
    
    class U4DStaticModel:public U4DModel{
        
        private:
            
            bool collisionEnabled;
            
            bool broadPhaseBoundingVolumeVisibility;
        
            bool narrowPhaseBoundingVolumeVisibility;
        
            //Narrow Phase Bounding Volume
            U4DBoundingVolume *convexHullBoundingVolume;
        
            //Broad Phase Bounding Volume
            U4DBoundingVolume *sphereBoundingVolume;
        
            MassProperties massProperties;
        
            CollisionProperties collisionProperties;
        
            ConvexHullProperties convexHullProperties;
        
            float coefficientOfRestitution;
        
            bool isPlatform;
        
        protected:
            
        public:
        
            U4DStaticModel();
            
            ~U4DStaticModel();
            
            U4DStaticModel(const U4DStaticModel& value);
            
            U4DStaticModel& operator=(const U4DStaticModel& value);
        
            //Init operations
            void initMass(float uMass);
        
            void initCenterOfMass(U4DVector3n& uCenterOfMass);
            
            void initCoefficientOfRestitution(float uValue);
            
            void initInertiaTensorType(INERTIATENSORTYPE uInertiaTensorType);
            
            void initAsPlatform(bool uValue);
        
            //Set Operations
        
            void setNarrowPhaseBoundingVolumeVisibility(bool uValue);
            
            void setBroadPhaseBoundingVolumeVisibility(bool uValue);
            
                //These set operations should be make private
                
                void setCollisionNormalFaceDirection(U4DVector3n& uNormalFaceDirection);
                
                void setCollisionPenetrationDepth(float uPenetrationDepth);
                
                void setNormalForce(U4DVector3n& uNormalForce);
                
                void setModelHasCollided(bool uValue);
        
            //Behavior operations
        
            void enableCollisionBehavior();
            
            void pauseCollisionBehavior();
            
            void resumeCollisionBehavior();
            
            bool isCollisionBehaviorEnabled();
        
            //Compute operations
            void computeInertiaTensor();
            
            //Update operations
            void updateConvexHullVertices();
            
            void updateNarrowPhaseBoundingVolumeSpace();
            
            void updateBroadPhaseBoundingVolumeSpace();
        
            //add operations
       
            void addCollisionContactPoint(U4DVector3n& uContactPoint);
        
            //clear operations
            void clearConvexHullVertices();
        
            void clearCollisionInformation();
            
            //Get Operations
            
            float getMass()const;
            
            U4DVector3n getCenterOfMass();
            
            float getCoefficientOfRestitution();
            
            INERTIATENSORTYPE getInertiaTensorType();
            
            bool getIsPlatform();
        
            U4DMatrix3n getMomentOfInertiaTensor();
            
            U4DMatrix3n getInverseMomentOfInertiaTensor();
        
            std::vector<U4DVector3n>& getConvexHullVertices();
        
            int getConvexHullVerticesCount();
        
            U4DBoundingVolume* getNarrowPhaseBoundingVolume();
        
            bool getNarrowPhaseBoundingVolumeVisibility();
        
            U4DBoundingVolume* getBroadPhaseBoundingVolume();
        
            bool getBroadPhaseBoundingVolumeVisibility();
        
            U4DVector3n getNormalForce();
        
            std::vector<U4DVector3n> getCollisionContactPoints();
        
            void clearCollisionContactPoints();
        
            U4DVector3n getCollisionNormalFaceDirection();
            
            float getCollisionPenetrationDepth();
        
            bool getModelHasCollided();
        
        };
    
}

#endif /* defined(__UntoldEngine__U4DStaticModel__) */
