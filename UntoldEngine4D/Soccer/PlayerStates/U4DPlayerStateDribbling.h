//
//  U4DPlayerStateDribbling.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateDribbling_hpp
#define U4DPlayerStateDribbling_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateDribbling:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateDribbling();
        
        ~U4DPlayerStateDribbling();
        
    public:
        
        static U4DPlayerStateDribbling* instance;
        
        static U4DPlayerStateDribbling* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}

#endif /* U4DPlayerStateDribbling_hpp */
