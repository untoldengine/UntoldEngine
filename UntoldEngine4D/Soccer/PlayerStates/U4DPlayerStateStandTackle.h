//
//  U4DPlayerStateStandTackle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/9/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateStandTackle_hpp
#define U4DPlayerStateStandTackle_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateStandTackle:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateStandTackle();
        
        ~U4DPlayerStateStandTackle();
        
    public:
        
        static U4DPlayerStateStandTackle* instance;
        
        static U4DPlayerStateStandTackle* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateStandTackle_hpp */
