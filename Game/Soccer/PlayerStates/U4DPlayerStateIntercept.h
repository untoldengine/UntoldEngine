//
//  U4DPlayerStateIntercept.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateIntercept_hpp
#define U4DPlayerStateIntercept_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateIntercept:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateIntercept();
        
        ~U4DPlayerStateIntercept();
        
    public:
        
        static U4DPlayerStateIntercept* instance;
        
        static U4DPlayerStateIntercept* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateIntercept_hpp */
