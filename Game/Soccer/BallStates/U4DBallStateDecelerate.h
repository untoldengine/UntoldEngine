//
//  U4DBallStateDecelerate.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBallStateDecelerate_hpp
#define U4DBallStateDecelerate_hpp

#include <stdio.h>
#include "U4DBallStateInterface.h"

namespace U4DEngine {

    class U4DBallStateDecelerate:public U4DBallStateInterface {

    private:

        U4DBallStateDecelerate();
        
        ~U4DBallStateDecelerate();
        
    public:
        
        static U4DBallStateDecelerate* instance;
        
        static U4DBallStateDecelerate* sharedInstance();
        
        void enter(U4DBall *uBall);
        
        void execute(U4DBall *uBall, double dt);
        
        void exit(U4DBall *uBall);
        
        bool isSafeToChangeState(U4DBall *uBall);
        
        bool handleMessage(U4DBall *uBall, Message &uMsg);
        
    };

}
#endif /* U4DBallStateDecelerate_hpp */
