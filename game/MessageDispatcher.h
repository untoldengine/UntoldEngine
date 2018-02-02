//
//  MessageDispatcher.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef MessageDispatcher_hpp
#define MessageDispatcher_hpp

#include <stdio.h>

class GuardianModel;

class MessageDispatcher {
    
private:
    
    MessageDispatcher();
    ~MessageDispatcher();
    
public:
    
    static MessageDispatcher* instance;
    static MessageDispatcher* sharedInstance();
    
    void sendMessage(double uDelay, GuardianModel *uSender, GuardianModel *uReceiver, int uMsg);
    
    void sendMessage(double uDelay, GuardianModel *uSender, GuardianModel *uReceiver, int uMsg, void* uExtraInfo);

    void sendDelayedMessages();
    
};
#endif /* MessageDispatcher_hpp */
