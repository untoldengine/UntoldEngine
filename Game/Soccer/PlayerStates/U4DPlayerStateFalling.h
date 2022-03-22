//
//  U4DPlayerStateFalling.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateFalling_hpp
#define U4DPlayerStateFalling_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateFalling:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateFalling();
        
        ~U4DPlayerStateFalling();
        
    public:
        
        static U4DPlayerStateFalling* instance;
        
        static U4DPlayerStateFalling* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateFalling_hpp */
