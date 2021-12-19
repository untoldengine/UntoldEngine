//
//  U4DPlayerStateJog.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/16/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateJog_hpp
#define U4DPlayerStateJog_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateJog:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateJog();
        
        ~U4DPlayerStateJog();
        
    public:
        
        static U4DPlayerStateJog* instance;
        
        static U4DPlayerStateJog* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}

#endif /* U4DPlayerStateJog_hpp */
