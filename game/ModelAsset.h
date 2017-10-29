//
//  ModelAsset.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef ModelAsset_hpp
#define ModelAsset_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "U4DParticleSystem.h"
#include "CommonProtocols.h"

class ModelAsset:public U4DEngine::U4DGameObject {
    
private:
    
    U4DEngine::U4DParticleSystem *particleSystem;
    U4DEngine::PARTICLESYSTEMDATA particleSystemData;
    
public:
    
    ModelAsset();
    
    ~ModelAsset();
    
    void init(const char* uModelName, const char* uBlenderFile);
    
    void update(double dt);
    
    void loadParticleSystemInfo(U4DEngine::PARTICLESYSTEMDATA &uParticleSystemData);
    
    void startParticleSystem();
    
};
#endif /* ModelAsset_hpp */
