//
//  U4DBallStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBallStateInterface_hpp
#define U4DBallStateInterface_hpp

#include <stdio.h>
#include "U4DBall.h"
#include "CommonProtocols.h"

namespace U4DEngine {

class U4DBallStateInterface {
        
private:
    
public:
    
    std::string name;
    
    virtual ~U4DBallStateInterface(){};
    
    virtual void enter(U4DBall *uBall)=0;
    
    virtual void execute(U4DBall *uBall, double dt)=0;
    
    virtual void exit(U4DBall *uBall)=0;
    
    virtual bool handleMessage(U4DBall *uBall, Message &uMsg)=0;
    
    virtual bool isSafeToChangeState(U4DBall *uBall)=0;
    
};

}
#endif /* U4DBallStateInterface_hpp */
