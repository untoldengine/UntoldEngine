//
//  Constants.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/21/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef UntoldEngine_Constants_h
#define UntoldEngine_Constants_h

namespace U4DEngine {
    
    /**
     @brief Constant representing the value of Pi
     */
    const float PI=3.141592653589793;
    
    /**
     @brief Constant representing a sleep-epsilon value used to bring a 3D model to sleep
     */
    const float sleepEpsilon=0.96;
    
    /**
     @brief Constant which represents a sleep bias used to bring a 3D model to sleep. This bias is used to slowly bring the model to sleep instead of doing it abruptaly
     */
    const float sleepBias=0.5;
    
    /**
     @brief Constant which represents the distance epsilon the engine will interpret as a collision
     */
    const float collisionDistanceEpsilon=1.0e-4f;
    
    /**
     @brief Constant which represents the minimum time of impact during a collision
     */
    const float minimumTimeOfImpact=0.2;
    
    /**
     @brief Constant which represents the minimum cutoff distance to accept contact point
     */
    const float minimumManifoldCutoffDistance=0.01;
    
    /**
     @brief Constant which represents the cutoff angle between manifold colliding planes. When a Collision occurs at angles smaller than this.
     The entities angular velocity are reduced to prevent any penetration during collision.
    */
    const float minimumManifoldPlaneCollisionAngle=5.0;
    
    /**
     @brief Constant which represents a barycentric epsilon
     */
    const float barycentricEpsilon=1.0;
    
    /**
     @brief Constant which represents the time-step used in the engine
     */
    const float timeStep=0.01;
    
    /**
     @brief Constant which represents a zero in the engine
     */
    const float zeroEpsilon=1.0e-4f;
    
    /**
     @brief Constant used during plane intersection tests. It represents a zero distance
     */
    const float zeroPlaneIntersectionEpsilon=1.0e-3f;
    
    /**
     @brief Constant used to represent the minimum impulse allowed between collisions
     */
    const float impulseCollisionMinimum=0.0;
    
    /**
     @brief Constant which represents the Runga-Kutta correction coefficient
     */
    const float rungaKuttaCorrectionCoefficient=0.7;
    
    /**
     @brief Constant used to represent if a point is inside/outside a plane
     */
    const float planeBoundaryEpsilon=1.0e-4f;
    
    /**
     @brief Constant used as the shadow mapping texture width
     */
    const float depthShadowWidth=1024;
    
    /**
     @brief Constant used as the shadow mapping texture height
     */
    const float depthShadowHeight=1024;
    
    /**
     @brief Constant used as maximum file size of a shader
     */
    const int   maxShaderLength=8192;
    
    /**
     @brief Animation blending delay
     */
    const float animationBlendingDelay=0.001;
    
    /**
     @brief button touch epsilon value
     */
    const float buttonTouchEpsilon=1.0e-1f;
    
    /**
     @brief Padding for the AABB Bounding volume. For no padding, set it equal to 1.0
     */
    const float aabbBoundingVolumePadding=1.50;
    
    /**
     @brief Padding for the Sphere Bounding volume. For no padding, set it equal to 0.50
     */
    const float sphereBoundingVolumePadding=0.57;
    
    /**
     @brief Minimum number of contact points for an object to be consider in equilibrium
     */
    const int minimumContactPointsForEquilibrium=3;
    
    /**
     @brief The rate of particles being emitted
     */
    const float particleEmissionRate=0.01;
    
    /**
     @brief A divider scaler for the speed of the particle. Using this so that it matches the speed of the particle loader
     */
    const float particleSpeedDivider=400.0;
    
    /**
     @brief A divider scaler for the position variance of the particle. Using this so that it matches the speed of the particle loader
     */
    const float particlePositionDivider=248.0;
    
    /**
     @brief A divider scaler for the angular acceleration of the particle. Using this so that it matches the speed of the particle loader
     */
    const float particleAngularAccelDivider=5.0;
    
    /**
     @brief padding for ui elements
     */
    const float uiPadding=0.02;
    
}

#endif
