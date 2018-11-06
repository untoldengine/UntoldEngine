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
        U4DVector3n color;
        
        /**
         @brief particle's start color
         */
        U4DVector3n startColor;
        
        /**
         @brief particle's end color
         */
        U4DVector3n endColor;
        
        /**
         @brief particle's change in color
         */
        U4DVector3n deltaColor;
        
        /**
         @brief particle's start color variance
         */
        U4DVector3n startColorVariance;
        
        /**
         @brief particle's end color variance
         */
        U4DVector3n endColorVariance;
        
        /**
         @brief particle's position variance
         */
        U4DVector3n positionVariance;
        
        /**
         @brief particle's emit angle
         */
        U4DVector3n emitAngle;
        
        /**
         @brief particle's emit angle variance
         */
        U4DVector3n emitAngleVariance;
        
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
        
    };
    
}


#endif /* U4DParticleData_hpp */
