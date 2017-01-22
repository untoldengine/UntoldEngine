//
//  U4DParticles.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DParticles_hpp
#define U4DParticles_hpp

#include <stdio.h>
#include "U4DVisibleEntity.h"
#include "U4DParticleData.h"

namespace U4DEngine {
    
    class U4DParticle:public U4DVisibleEntity {
        
    private:
        
    protected:

    /**
     @brief document this
     */
    int numberOfParticles;
    
    /**
     @brief document this
     */
    float animationElapseTime;
    
    public:
        
        /**
         @brief Object which contains attribute data such as vertices
         */
        U4DParticleData particleCoordinates;
        
        /**
         @brief Constructor of class
         */
        U4DParticle();
        
        /**
         @brief Destructor of class
         */
        ~U4DParticle();
        
        /**
         @brief Method which starts the rendering process of the entity
         */
        void draw();

        /**
         @brief Document this
         */
        void setNumberOfParticles(int uNumberOfParticles);

        /**
         @brief Document this
         */
        int getNumberOfParticles();
        
        /**
         @brief Document this
         */
        void setParticlesVertices();
        
        /**
         @brief document this
         */
        
        void setAnimationElapseTime(float uAnimationElapseTime);
        
        /**
         @brief Document this
         */
        float mix(float x, float y, float a);
        
    };
    
}

#endif /* U4DParticles_hpp */
