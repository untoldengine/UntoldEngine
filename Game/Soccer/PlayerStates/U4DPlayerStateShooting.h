//
//  U4DPlayerStateShooting.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateShooting_hpp
#define U4DPlayerStateShooting_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateShooting:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateShooting();
        
        ~U4DPlayerStateShooting();
        
    public:
        
        static U4DPlayerStateShooting* instance;
        
        static U4DPlayerStateShooting* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}

#endif /* U4DPlayerStateShooting_hpp */
