//
//  U4DPlayerStateHalt.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/16/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateHalt_hpp
#define U4DPlayerStateHalt_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateHalt:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateHalt();
        
        ~U4DPlayerStateHalt();
        
    public:
        
        static U4DPlayerStateHalt* instance;
        
        static U4DPlayerStateHalt* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateHalt_hpp */
