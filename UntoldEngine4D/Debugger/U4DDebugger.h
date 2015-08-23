//
//  U4DLight.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DDebugger__
#define __UntoldEngine__U4DDebugger__

#include <iostream>
#include <vector>
#include "U4DEntity.h"
#include "U4DVisibleEntity.h"
#include "U4DVertexData.h"
#include "CommonProtocols.h"

namespace U4DEngine {
class U4DEntity;
}

namespace U4DEngine {
    
class U4DDebugger:public U4DVisibleEntity{
    
private:
    
public:
    
    U4DVertexData bodyCoordinates;
    std::vector<U4DEntity*> entityContainer;
    
    U4DDebugger();
    
    ~U4DDebugger(){};
    
    void draw();
    void addEntityToDebug(U4DEntity *uEntity);
    void buildEntityAxis();
};
    
}

#endif /* defined(__UntoldEngine__U4DDebugger__) */
