//
//  U4DPlayerStateSlidingTackle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/9/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateSlidingTackle_hpp
#define U4DPlayerStateSlidingTackle_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateSlidingTackle:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateSlidingTackle();
        
        ~U4DPlayerStateSlidingTackle();
        
    public:
        
        static U4DPlayerStateSlidingTackle* instance;
        
        static U4DPlayerStateSlidingTackle* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateSlidingTackle_hpp */
