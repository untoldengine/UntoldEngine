//
//  U4DPlayerStateAiDribbling.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/10/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayerStateAiDribbling_hpp
#define U4DPlayerStateAiDribbling_hpp

#include <stdio.h>
#include "U4DPlayerStateInterface.h"

namespace U4DEngine {

    class U4DPlayerStateAiDribbling:public U4DPlayerStateInterface {

    private:

        U4DPlayerStateAiDribbling();
        
        ~U4DPlayerStateAiDribbling();
        
    public:
        
        static U4DPlayerStateAiDribbling* instance;
        
        static U4DPlayerStateAiDribbling* sharedInstance();
        
        void enter(U4DPlayer *uPlayer);
        
        void execute(U4DPlayer *uPlayer, double dt);
        
        void exit(U4DPlayer *uPlayer);
        
        bool isSafeToChangeState(U4DPlayer *uPlayer);
        
        bool handleMessage(U4DPlayer *uPlayer, Message &uMsg);
        
    };

}
#endif /* U4DPlayerStateAiDribbling_hpp */
