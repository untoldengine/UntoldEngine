//
//  GoldEatenState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef GoldEatenState_hpp
#define GoldEatenState_hpp

#include <stdio.h>
#include "GoldStateInterface.h"
#include "UserCommonProtocols.h"

class GoldEatenState:public GoldStateInterface {
    
private:
    
    GoldEatenState();
    
    ~GoldEatenState();
    
public:
    
    static GoldEatenState* instance;
    
    static GoldEatenState* sharedInstance();
    
    void enter(GoldAsset *uGold);
    
    void execute(GoldAsset *uGold, double dt);
    
    void exit(GoldAsset *uGold);
    
    bool isSafeToChangeState(GoldAsset *uGold);
    
    bool handleMessage(GoldAsset *uGold, Message &uMsg);
    
};

#endif /* GoldEatenState_hpp */
