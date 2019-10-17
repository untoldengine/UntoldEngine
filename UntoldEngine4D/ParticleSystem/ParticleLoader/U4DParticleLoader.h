//
//  U4DParticleLoader.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/1/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleLoader_hpp
#define U4DParticleLoader_hpp

#include <stdio.h>

#include <iostream>
#include <vector>
#include "tinyxml2.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
    /**
     @ingroup loader
     @brief The U4DParticleLoader class is in charge of importing 3D particle assets.
     */
    class U4DParticleLoader{
        
    private:
        
        /**
         @brief XML document read by the loader
         */
        tinyxml2::XMLDocument doc;
        
        /**
         @brief Name of the currently imported file
         */
        std::string currentLoadedFile;
        
        
        
    public:
        
        /**
         @brief Constructor for the particle system loader
         */
        U4DParticleLoader();
        
        /**
         @brief Destructor for the particle system loader
         */
        ~U4DParticleLoader();
        
        /**
         @brief structure containing information about the particle, emitter and particle system
         */
        U4DEngine::PARTICLESYSTEMDATA particleSystemData;
        
        /**
         @brief loads the particle asset file. Currently, the file loaded is from Particle Designer
         @param uParticleAssetFile Particle Designer file. The format is PEX
         
         @return true if the particle was properly loaded
         */
        bool loadParticleAssetFile(std::string uParticleAssetFile);
        
        /**
         @brief reads the particle data loaded from Particle Designer PEX file and loads the data into the ParticleSystemData structure
         */
        void loadParticleData();
        
        /**
         @brief maps the corresponding opengl blending factors to metal blending factors
         @param uBlending opengl blending factor
         
         @return metal blending factor
         */
        int blendingFactorMapping(int uBlending);
        
    };
    
}

#endif /* U4DParticleLoader_hpp */
