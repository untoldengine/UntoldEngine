//
//  U4DBallStateKicked.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBallStateKicked_hpp
#define U4DBallStateKicked_hpp

#include <stdio.h>
#include "U4DBallStateInterface.h"

namespace U4DEngine {

    class U4DBallStateKicked:public U4DBallStateInterface {

    private:

        U4DBallStateKicked();
        
        ~U4DBallStateKicked();
        
    public:
        
        static U4DBallStateKicked* instance;
        
        static U4DBallStateKicked* sharedInstance();
        
        void enter(U4DBall *uBall);
        
        void execute(U4DBall *uBall, double dt);
        
        void exit(U4DBall *uBall);
        
        bool isSafeToChangeState(U4DBall *uBall);
        
        bool handleMessage(U4DBall *uBall, Message &uMsg);
        
    };

}
#endif /* U4DBallStateKicked_hpp */
