//
//  U4DPlayerStateGoHome.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/3/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateGoHome_hpp
#define U4DPlayerStateGoHome_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateGoHome:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateGoHome();
        
        ~U4DPlayerStateGoHome();
        
    public:
        
        static U4DPlayerStateGoHome* instance;
        
        static U4DPlayerStateGoHome* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}


#endif /* U4DPlayerStateGoHome_hpp */
