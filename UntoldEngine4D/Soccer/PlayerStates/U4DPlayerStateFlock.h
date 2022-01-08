//
//  U4DPlayerStateFlock.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateFlock_hpp
#define U4DPlayerStateFlock_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateFlock:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateFlock();
        
        ~U4DPlayerStateFlock();
        
    public:
        
        static U4DPlayerStateFlock* instance;
        
        static U4DPlayerStateFlock* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateFlock_hpp */
