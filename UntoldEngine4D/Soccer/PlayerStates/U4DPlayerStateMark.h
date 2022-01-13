//
//  U4DPlayerStateMark.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/9/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateMark_hpp
#define U4DPlayerStateMark_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateMark:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateMark();
        
        ~U4DPlayerStateMark();
        
    public:
        
        static U4DPlayerStateMark* instance;
        
        static U4DPlayerStateMark* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateMark_hpp */
