//
//  MessageDispatcher.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef MessageDispatcher_hpp
#define MessageDispatcher_hpp

#include <stdio.h>

class Player;
class Team;

class MessageDispatcher {
    
private:
    
    static MessageDispatcher *instance;
    
protected:
    
    MessageDispatcher();
    
    ~MessageDispatcher();

public:
    
    static MessageDispatcher *sharedInstance();
    
    void sendMessage(double uDelay, Player *uSenderPlayer, Player *uReceiverPlayer, int uMsg);

    void sendMessage(double uDelay, Player *uSenderPlayer, Player *uReceiverPlayer, int uMsg, void* uExtraInfo);
    
    void sendMessage(double uDelay, Team *uTeam, Player *uReceiverPlayer, int uMsg);
    
    void sendMessage(double uDelay, Team *uReceiverTeam, int uMsg);
};

#endif /* MessageDispatcher_hpp */
