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

namespace U4DEngine {
    
    class U4DBoundingVolume;
    
}

namespace U4DEngine {
    
    typedef struct{
     
        std::vector<U4DVector3n> convexHullVertices;
    
    }ConvexHullProperties;
    
    typedef struct{
        
        float mass=0.0;
        U4DVector3n centerOfMass;
        U4DMatrix3n momentOfInertiaTensor;
        U4DMatrix3n inverseMomentOfInertiaTensor;
        
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
        
        protected:
            
        public:
        
            U4DStaticModel();
            
            ~U4DStaticModel();
            
            U4DStaticModel(const U4DStaticModel& value);
            
            U4DStaticModel& operator=(const U4DStaticModel& value);
        
            void setMass(float uMass);
            
            float getMass()const;
            
            void setCenterOfMass(U4DVector3n& uCenterOfMass);
            
            U4DVector3n getCenterOfMass();
            
            void setCoefficientOfRestitution(float uValue);
            
            float getCoefficientOfRestitution();
            
            void setInertiaTensor(float uLength, float uWidth, float uHeight);
            
            U4DMatrix3n getMomentOfInertiaTensor();
            
            U4DMatrix3n getInverseMomentOfInertiaTensor();
            
            void integralTermsForTensor(float w0,float w1,float w2,float &f1,float &f2, float &f3,float &g0,float &g1,float &g2);
        
            void updateConvexHullVertices();
        
            void clearConvexHullVertices();
        
            std::vector<U4DVector3n>& getConvexHullVertices();
        
            int getConvexHullVerticesCount();
        
            void enableCollision();
            
            void pauseCollision();
            
            void resumeCollision();
            
            bool isCollisionEnabled();
            
            void allowCollisionWith();
        
            //Narrow Phase Bounding Volume
            U4DBoundingVolume* getNarrowPhaseBoundingVolume();
        
            void setNarrowPhaseBoundingVolumeVisibility(bool uValue);
            
            bool getNarrowPhaseBoundingVolumeVisibility();
            
            void updateNarrowPhaseBoundingVolumeSpace();
        
        
            //Broad Phase Bounding Volume
        
            U4DBoundingVolume* getBroadPhaseBoundingVolume();
        
            void setBroadPhaseBoundingVolumeVisibility(bool uValue);
            
            bool getBroadPhaseBoundingVolumeVisibility();
            
            void updateBroadPhaseBoundingVolumeSpace();
        
            void addCollisionContactPoint(U4DVector3n& uContactPoint);
        
            void setCollisionNormalFaceDirection(U4DVector3n& uNormalFaceDirection);
            
            void setCollisionPenetrationDepth(float uPenetrationDepth);
        
            void setNormalForce(U4DVector3n& uNormalForce);
        
            U4DVector3n getNormalForce();
        
            std::vector<U4DVector3n> getCollisionContactPoints();
        
            void clearCollisionContactPoints();
        
            U4DVector3n getCollisionNormalFaceDirection();
            
            float getCollisionPenetrationDepth();
        
            void setModelHasCollided(bool uValue);
        
            bool getModelHasCollided();
        
            void resetCollisionInformation();
        
        };
    
}

#endif /* defined(__UntoldEngine__U4DStaticModel__) */
