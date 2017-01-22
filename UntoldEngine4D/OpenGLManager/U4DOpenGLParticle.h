//
//  U4DOpenGLParticle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DOpenGLParticle_hpp
#define U4DOpenGLParticle_hpp

#include <stdio.h>
#include "U4DOpenGLManager.h"

namespace U4DEngine {
    class U4DParticle;
}

namespace U4DEngine {
    
    /**
     @brief The U4DOpenGLParticle is in charge of rendering particle entities
     */
    class U4DOpenGLParticle:public U4DOpenGLManager{
        
    private:
        
        
    protected:
        
        /**
         @brief Pointer representing a particle entity
         */
        U4DParticle* u4dObject;
        
    public:
        
        /**
         @brief Constructor for the class
         
         @param uU4DParticle takes as a paramenter the entity representing the particle entity
         */
        U4DOpenGLParticle(U4DParticle* uU4DParticles);
        
        /**
         @brief Destructor for the class
         */
        ~U4DOpenGLParticle();
        
        /**
         @brief Method which starts the glDrawElements routine
         */
        void drawElements();
        
        /**
         @brief Method which returns the absolute space of the entity
         
         @return Returns the entity absolure space-Orientation and Position
         */
        U4DDualQuaternion getEntitySpace();
        
        /**
         @brief Method which returns the local space of the entity
         
         @return Returns the entity local space-Orientation and Position
         */
        U4DDualQuaternion getEntityLocalSpace();
        
        /**
         @brief Method which returns the absolute position of the entity
         
         @return Returns the entity absolute position
         */
        U4DVector3n getEntityAbsolutePosition();
        
        /**
         @brief Method which returns the local position of the entity
         
         @return Returns the entity local position
         */
        U4DVector3n getEntityLocalPosition();
        
        /**
         @brief Method which loads all Vertex Object Buffers used in rendering
         */
        void loadVertexObjectBuffer();
        
        /**
         @brief Method which enables the Vertices Attributes locations
         */
        void enableVerticesAttributeLocations();
        
        
    };
}
#endif /* U4DOpenGLParticle_hpp */
