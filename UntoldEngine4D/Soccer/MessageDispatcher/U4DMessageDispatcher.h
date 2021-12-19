//
//  U4DMessageDispatcher.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMessageDispatcher_hpp
#define U4DMessageDispatcher_hpp

#include <stdio.h>

namespace U4DEngine {

class U4DPlayer;
class U4DTeam;

class U4DMessageDispatcher {
    
private:
    
    static U4DMessageDispatcher *instance;
    
protected:
    
    U4DMessageDispatcher();
    
    ~U4DMessageDispatcher();

public:
    
    static U4DMessageDispatcher *sharedInstance();
    
    void sendMessage(double uDelay, U4DPlayer *uSenderPlayer, U4DPlayer *uReceiverPlayer, int uMsg);

    void sendMessage(double uDelay, U4DPlayer *uSenderPlayer, U4DPlayer *uReceiverPlayer, int uMsg, void* uExtraInfo);
    
    void sendMessage(double uDelay, U4DTeam *uTeam, U4DPlayer *uReceiverPlayer, int uMsg);
    
    void sendMessage(double uDelay, U4DTeam *uReceiverTeam, int uMsg);
};

}

#endif /* U4DMessageDispatcher_hpp */
