//
//  GoldStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef GoldStateInterface_hpp
#define GoldStateInterface_hpp

#include <stdio.h>
#include "UserCommonProtocols.h"
#include "GoldAsset.h"

class GoldStateInterface {
    
    
public:
    virtual ~GoldStateInterface(){};
    
    virtual void enter(GoldAsset *uGold)=0;
    
    virtual void execute(GoldAsset *uGold, double dt)=0;
    
    virtual void exit(GoldAsset *uGold)=0;
    
    virtual bool handleMessage(GoldAsset *uGold, Message &uMsg)=0;
    
    virtual bool isSafeToChangeState(GoldAsset *uGold)=0;
    
};
#endif /* GoldStateInterface_hpp */
