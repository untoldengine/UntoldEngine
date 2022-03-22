//
//  U4DBallStateDribbling.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBallStateDribbling_hpp
#define U4DBallStateDribbling_hpp

#include <stdio.h>
#include "U4DBallStateInterface.h"

namespace U4DEngine {

    class U4DBallStateDribbling:public U4DBallStateInterface {

    private:

        U4DBallStateDribbling();
        
        ~U4DBallStateDribbling();
        
    public:
        
        static U4DBallStateDribbling* instance;
        
        static U4DBallStateDribbling* sharedInstance();
        
        void enter(U4DBall *uBall);
        
        void execute(U4DBall *uBall, double dt);
        
        void exit(U4DBall *uBall);
        
        bool isSafeToChangeState(U4DBall *uBall);
        
        bool handleMessage(U4DBall *uBall, Message &uMsg);
        
    };

}
#endif /* U4DBallStateDribbling_hpp */
