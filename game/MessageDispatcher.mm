//
//  MessageDispatcher.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "MessageDispatcher.h"
#include "GuardianModel.h"
#include "U4DDirector.h"
#include "UserCommonProtocols.h"

MessageDispatcher *MessageDispatcher::instance=0;

MessageDispatcher::MessageDispatcher(){
    
}

MessageDispatcher::~MessageDispatcher(){
    
}

MessageDispatcher *MessageDispatcher::sharedInstance(){
    
    
    if (instance==0) {
        instance=new MessageDispatcher();
    }
    
    return instance;
    
}

void MessageDispatcher::sendMessage(double uDelay, GuardianModel *uSender, GuardianModel *uReceiver, int uMsg){
    
    //if the receiver player is null, then don't send message
    
    if (uReceiver!=nullptr) {
        //create the message
        Message message;
        
        message.sender=uSender;
        message.receiver=uReceiver;
        message.msg=uMsg;
        
        //send the message
        uReceiver->handleMessage(message);
        
    }
}

void MessageDispatcher::sendMessage(double uDelay, GuardianModel *uSender, GuardianModel *uReceiver, int uMsg, void* uExtraInfo){
    
    //if the receiver player is null, then don't send message
    
    if (uReceiver!=nullptr) {
        //create the message
        Message message;
        
        message.sender=uSender;
        message.receiver=uReceiver;
        message.msg=uMsg;
        message.extraInfo=uExtraInfo;
        
        //send the message
        uReceiver->handleMessage(message);
        
    }
    
}

