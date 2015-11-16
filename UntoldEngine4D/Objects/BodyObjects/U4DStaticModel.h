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
        
        float mass=0.0;
        U4DVector3n centerOfMass;
        U4DMatrix3n momentOfInertiaTensor;
        U4DMatrix3n inverseMomentOfInertiaTensor;
        std::vector<U4DVector3n> vertexDistanceFromCenterOfMass;
        
    }MassProperties;

    typedef struct{
        
        U4DVector3n contactPoint; //contact points (e.g. against plane, OBB, etc)
        U4DVector3n normalForce;
        U4DVector3n normalDirection;
        float penetrationDepth=0.0;
        
    }ContactManifoldInformation;

    typedef struct{
        
        ContactManifoldInformation contactManifoldInformation;
        bool collided=false; //did the model collided
        
    }CollisionProperties;
}


namespace U4DEngine {
    
    class U4DStaticModel:public U4DModel{
        
        private:
            
            bool collisionEnabled;
            
            bool boundingBoxVisibility;
            
            U4DBoundingVolume *convexHullBoundingVolume;
        
            MassProperties massProperties;
        
            CollisionProperties collisionProperties;
        
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
            
            void setInertiaTensor(float uRadius);
            
            void setInertiaTensor(float uLength, float uWidth, float uHeight);
            
            U4DMatrix3n getMomentOfInertiaTensor();
            
            U4DMatrix3n getInverseMomentOfInertiaTensor();
            
            void integralTermsForTensor(float w0,float w1,float w2,float &f1,float &f2, float &f3,float &g0,float &g1,float &g2);
            
            void setVertexDistanceFromCenterOfMass();
            
            void enableCollision();
            
            void pauseCollision();
            
            void resumeCollision();
            
            bool isCollisionEnabled();
            
            void allowCollisionWith();
            
            void setBoundingBoxVisibility(bool uValue);
            
            bool getBoundingBoxVisibility();
            
            void updateBoundingBoxSpace();
            
            U4DBoundingVolume* getBoundingVolume();
            
            void setCollisionContactPoint(U4DVector3n& uContactPoint);
            
            void setCollisionNormalDirection(U4DVector3n& uNormalDirection);
            
            void setCollisionPenetrationDepth(float uPenetrationDepth);
        
            void setNormalForce(U4DVector3n& uNormalForce);
        
            U4DVector3n getNormalForce();
        
            U4DVector3n getCollisionContactPoint();
            
            U4DVector3n getCollisionNormalDirection();
            
            float getCollisionPenetrationDepth();
        
            void setModelHasCollided(bool uValue);
        
            bool getModelHasCollided();
        };
    
}

#endif /* defined(__UntoldEngine__U4DStaticModel__) */
