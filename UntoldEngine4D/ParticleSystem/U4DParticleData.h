//
//  U4DParticleData.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleData_hpp
#define U4DParticleData_hpp

#include <stdio.h>
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DIndex.h"
#include <vector>

namespace U4DEngine {
    
    /**
     @ingroup particlesystem
     @brief The U4DParticleData class contains all the behavior properties of a 3D particle such as start-color, end-color, life, speed
     */
    class U4DParticleData {
        
    private:
        
    public:
        
        /**
         @brief class constructor
         */
        U4DParticleData();
        
        /**
         @brief class destructor
         */
        ~U4DParticleData();
        
        /**
         @brief particle's color
         */
        U4DVector4n color;
        
        /**
         @brief particle's start color
         */
        U4DVector4n startColor;
        
        /**
         @brief particle's end color
         */
        U4DVector4n endColor;
        
        /**
         @brief particle's change in color
         */
        U4DVector4n deltaColor;
        
        /**
         @brief particle's start color variance
         */
        U4DVector4n startColorVariance;
        
        /**
         @brief particle's end color variance
         */
        U4DVector4n endColorVariance;
        
        /**
         @brief particle's position variance
         */
        U4DVector3n positionVariance;
        
        /**
         @brief particle's emit angle
         */
        float emitAngle;
        
        /**
         @brief particle's emit angle variance
         */
        float emitAngleVariance;
        
        /**
         @brief particle's Torus major radius. This is used if the emitter's behavior is the Torus
         */
        float torusMajorRadius;
        
        /**
         @brief particle's Torus minor radius. This is used if the emitter's behavior is the Torus
         */
        float torusMinorRadius;
        
        /**
         @brief particle's sphere radius. This is used if the emitter's behavior is the Sphere
         */
        float sphereRadius;
        
        /**
         @brief particle's life
         */
        float life;
        
        /**
         @brief particle's speed
         */
        float speed;
        
        /**
         @brief particle's speed variance
         */
        float speedVariance;
        
        /**
         @brief particle size
         */
        float particleSize;
        
        /**
         @brief particle start size
         */
        float startParticleSize;
        
        /**
         @brief particle start size variance
         */
        float startParticleSizeVariance;
        
        /**
         @brief particle end size
         */
        float endParticleSize;
        
        /**
         @brief particle end size variance
         */
        float endParticleSizeVariance;
        
        /**
         @brief particle's size change
         */
        float deltaParticleSize;
        
        /**
         @brief particle scale
         */
        float particleScaleFactor;
        
        /**
         @brief particle's radial acceleration
         */
        float particleRadialAcceleration;
        
        /**
         @brief particle's radial acceleration variance
         */
        float particleRadialAccelerationVariance;
        
        /**
         @brief particle's tangential acceleration
         */
        float particleTangentialAcceleration;
        
        /**
         @brief particle's tangential acceleration variance
         */
        float particleTangentialAccelerationVariance;
        
        /**
         @brief particle's gravity
         */
        U4DVector3n gravity;
        
        /**
         @brief particle's start rotation
         */
        float startParticleRotation;
        
        /**
         @brief particle's start rotation variance
         */
        float startParticleRotationVariance;
        
        /**
         @brief particle's end rotation
         */
        float endParticleRotation;
        
        /**
         @brief particle's end rotation variance
         */
        float endParticleRotationVariance;
        
        /**
         @brief particle's rotation change
         */
        float deltaParticleRotation;
        
        /**
         @brief particle rotation
         */
        float particleRotation;
        
    };
    
}


#endif /* U4DParticleData_hpp */
