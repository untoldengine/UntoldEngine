//
//  GoldAsset.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef GoldAsset_hpp
#define GoldAsset_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "U4DParticleSystem.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

class GoldStateInterface;
class GoldStateManager;

class GoldAsset:public U4DEngine::U4DGameObject {
    
private:
    
    GoldStateManager *stateManager;
    
    U4DEngine::U4DParticleSystem *particleSystem;
    
    U4DEngine::U4DCallback<GoldAsset> *scheduler;
    
    U4DEngine::U4DTimer *timer;
    
    U4DEngine::U4DEntity *goldAssetParent;
    
public:
    
    GoldAsset();
    
    ~GoldAsset();
    
    bool init(const char* uModelName, const char* uBlenderFile);
    
    void update(double dt);
    
    void removeFromScenegraph();
    
    void createParticle();
    
    void changeState(GoldStateInterface* uState);
    
    bool handleMessage(Message &uMsg);
    
    void selfDestroy();
};
#endif /* GoldAsset_hpp */
