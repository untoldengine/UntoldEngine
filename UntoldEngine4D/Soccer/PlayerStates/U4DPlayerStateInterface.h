//
//  U4DPlayerStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateInterface_hpp
#define U4DPlayerStateInterface_hpp

#include <stdio.h>
#include "U4DPlayer.h"
#include "CommonProtocols.h"

namespace U4DEngine {

class U4DPlayerStateInterface {
        
private:
    
public:
    
    std::string name;
    
    virtual ~U4DPlayerStateInterface(){};
    
    virtual void enter(U4DPlayer *uPlayer)=0;
    
    virtual void execute(U4DPlayer *uPlayer, double dt)=0;
    
    virtual void exit(U4DPlayer *uPlayer)=0;
    
    virtual bool handleMessage(U4DPlayer *uPlayer, Message &uMsg)=0;
    
    virtual bool isSafeToChangeState(U4DPlayer *uPlayer)=0;
    
};

}

#endif /* U4DPlayerStateInterface_hpp */
