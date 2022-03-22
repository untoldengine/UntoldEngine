//
//  U4DPlayerStateWalk.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/1/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateWalk_hpp
#define U4DPlayerStateWalk_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateWalk:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateWalk();
        
        ~U4DPlayerStateWalk();
        
    public:
        
        static U4DPlayerStateWalk* instance;
        
        static U4DPlayerStateWalk* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateWalk_hpp */
