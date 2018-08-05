//
//  GoldIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef GoldIdleState_hpp
#define GoldIdleState_hpp

#include <stdio.h>
#include "GoldStateInterface.h"
#include "UserCommonProtocols.h"

class GoldIdleState:public GoldStateInterface {
    
private:
    
    GoldIdleState();
    
    ~GoldIdleState();
    
public:
    
    static GoldIdleState* instance;
    
    static GoldIdleState* sharedInstance();
    
    void enter(GoldAsset *uGold);
    
    void execute(GoldAsset *uGold, double dt);
    
    void exit(GoldAsset *uGold);
    
    bool isSafeToChangeState(GoldAsset *uGold);
    
    bool handleMessage(GoldAsset *uGold, Message &uMsg);
    
};
#endif /* GoldIdleState_hpp */
