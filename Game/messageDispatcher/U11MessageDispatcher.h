//
//  U11MessageDispatcher.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11MessageDispatcher_hpp
#define U11MessageDispatcher_hpp

#include <stdio.h>
#include <string>

class U11Player;

class U11MessageDispatcher {
    
private:
    
    U11MessageDispatcher();
    ~U11MessageDispatcher();
    
public:
    
    static U11MessageDispatcher* instance;
    static U11MessageDispatcher* sharedInstance();
    
    void sendMessage(double uDelay, U11Player *uSenderPlayer, U11Player *uReceiverPlayer, int uMsg);
    
    void sendDelayedMessages();
    
};

#endif /* U11MessageDispatcher_hpp */
