//
//  U4DPlayerStateFree.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/18/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateFree_hpp
#define U4DPlayerStateFree_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateFree:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateFree();
        
        ~U4DPlayerStateFree();
        
    public:
        
        static U4DPlayerStateFree* instance;
        
        static U4DPlayerStateFree* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateFree_hpp */
