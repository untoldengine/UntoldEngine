//
//  U4DPlayerStatePass.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStatePass_hpp
#define U4DPlayerStatePass_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStatePass:public U4DPlayerStateInterface {

    private:

        bool passedBallSuccessfull;
        
        U4DPlayerStatePass();
        
        ~U4DPlayerStatePass();
        
    public:
        
        static U4DPlayerStatePass* instance;
        
        static U4DPlayerStatePass* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStatePass_hpp */
