//
//  U4DPlayerStateIdle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateIdle_hpp
#define U4DPlayerStateIdle_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateIdle:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateIdle();
        
        ~U4DPlayerStateIdle();
        
    public:
        
        static U4DPlayerStateIdle* instance;
        
        static U4DPlayerStateIdle* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}

#endif /* U4DPlayerStateIdle_hpp */
