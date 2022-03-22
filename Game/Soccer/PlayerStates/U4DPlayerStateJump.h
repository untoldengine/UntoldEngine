//
//  U4DPlayerStateJump.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/1/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateJump_hpp
#define U4DPlayerStateJump_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateJump:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateJump();
        
        ~U4DPlayerStateJump();
        
        float maxHeight;
        
    public:
        
        static U4DPlayerStateJump* instance;
        
        static U4DPlayerStateJump* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateJump_hpp */
