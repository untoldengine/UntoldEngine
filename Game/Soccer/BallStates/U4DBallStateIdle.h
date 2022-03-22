//
//  U4DBallStateIdle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBallStateIdle_hpp
#define U4DBallStateIdle_hpp

#include <stdio.h>
#include "U4DBallStateInterface.h"

namespace U4DEngine {

    class U4DBallStateIdle:public U4DBallStateInterface {

    private:

        U4DBallStateIdle();
        
        ~U4DBallStateIdle();
        
    public:
        
        static U4DBallStateIdle* instance;
        
        static U4DBallStateIdle* sharedInstance();
        
        void enter(U4DBall *uBall);
        
        void execute(U4DBall *uBall, double dt);
        
        void exit(U4DBall *uBall);
        
        bool isSafeToChangeState(U4DBall *uBall);
        
        bool handleMessage(U4DBall *uBall, Message &uMsg);
        
    };

}
#endif /* U4DBallStateIdle_hpp */
