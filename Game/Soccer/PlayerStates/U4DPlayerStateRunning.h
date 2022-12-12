//
//  U4DPlayerStateRunning.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/11/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateRunning_hpp
#define U4DPlayerStateRunning_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateRunning:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateRunning();
        
        ~U4DPlayerStateRunning();
        
    public:
        
        static U4DPlayerStateRunning* instance;
        
        static U4DPlayerStateRunning* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateRunning_hpp */
