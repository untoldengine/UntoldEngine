//
//  U11MessageDispatcher.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11MessageDispatcher.h"
#include "U11Player.h"
#include "U11Team.h"
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

void U11MessageDispatcher::sendMessage(double uDelay, U11Player *uSenderPlayer, U11Player *uReceiverPlayer, int uMsg){
    
    //if the receiver player is null, then don't send message
    
    if (uReceiverPlayer!=nullptr) {
        //create the message
        Message message;
        
        message.senderPlayer=uSenderPlayer;
        message.receiverPlayer=uReceiverPlayer;
        message.msg=uMsg;
        
        //send the message
        uReceiverPlayer->handleMessage(message);
        
    }
}

void U11MessageDispatcher::sendMessage(double uDelay, U11Player *uSenderPlayer, U11Player *uReceiverPlayer, int uMsg, void* uExtraInfo){
    
    //if the receiver player is null, then don't send message
    
    if (uReceiverPlayer!=nullptr) {
        //create the message
        Message message;
        
        message.senderPlayer=uSenderPlayer;
        message.receiverPlayer=uReceiverPlayer;
        message.msg=uMsg;
        message.extraInfo=uExtraInfo;
        
        //send the message
        uReceiverPlayer->handleMessage(message);
        
    }
    
}

void U11MessageDispatcher::sendMessage(double uDelay, U11Team *uReceiverTeam, int uMsg){
    
    if (uReceiverTeam!=nullptr) {
        //create the message
        Message message;
        
        message.receiverTeam=uReceiverTeam;
        message.msg=uMsg;
        
        //send the message
        uReceiverTeam->handleMessage(message);
        
    }
    
}

