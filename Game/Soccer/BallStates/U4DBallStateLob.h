//
//  U4DBallStateLob.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBallStateLob_hpp
#define U4DBallStateLob_hpp

#include <stdio.h>
#include "U4DBallStateInterface.h"

namespace U4DEngine {

    class U4DBallStateLob:public U4DBallStateInterface {

    private:

        U4DBallStateLob();
        
        ~U4DBallStateLob();
        
        float maxHeight;
        
    public:
        
        static U4DBallStateLob* instance;
        
        static U4DBallStateLob* sharedInstance();
        
        void enter(U4DBall *uBall);
        
        void execute(U4DBall *uBall, double dt);
        
        void exit(U4DBall *uBall);
        
        bool isSafeToChangeState(U4DBall *uBall);
        
        bool handleMessage(U4DBall *uBall, Message &uMsg);
        
    };

}
#endif /* U4DBallStateLob_hpp */
