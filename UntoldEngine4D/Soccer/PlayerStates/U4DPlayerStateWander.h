//
//  U4DPlayerStateWander.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateWander_hpp
#define U4DPlayerStateWander_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateWander:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateWander();
        
        ~U4DPlayerStateWander();
        
    public:
        
        static U4DPlayerStateWander* instance;
        
        static U4DPlayerStateWander* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateWander_hpp */
