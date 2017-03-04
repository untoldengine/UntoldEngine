//
//  U11MessageDispatcher.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11MessageDispatcher.h"
#include "U11Player.h"
#include "U4DDirector.h"
#include "UserCommonProtocols.h"

U11MessageDispatcher *U11MessageDispatcher::instance=0;

U11MessageDispatcher::U11MessageDispatcher(){
    
}

U11MessageDispatcher::~U11MessageDispatcher(){
    
}

U11MessageDispatcher *U11MessageDispatcher::sharedInstance(){
    
    
    if (instance==0) {
        instance=new U11MessageDispatcher();
    }
    
    return instance;
    
}

void U11MessageDispatcher::sendMessage(double uDelay, std::string uSenderName, std::string uReceiverName, int uMsg){
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    //get the reciever ID pointer's
    U11Player *player=dynamic_cast<U11Player*>(director->searchChild(uReceiverName));
    
    //if the player is null, then don't send message
    
    if (player!=nullptr) {
        //create the message
        Message message;
        
        message.senderName=uSenderName;
        message.receivedName=uReceiverName;
        message.msg=uMsg;
        
        //send the message
        player->handleMessage(message);
    }
}
