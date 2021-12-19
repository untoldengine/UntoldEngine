//
//  U4DMessageDispatcher.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DMessageDispatcher.h"
#include "U4DPlayer.h"
#include "U4DTeam.h"
#include "CommonProtocols.h"

namespace U4DEngine {

U4DMessageDispatcher* U4DMessageDispatcher::instance=0;

U4DMessageDispatcher::U4DMessageDispatcher(){
    
}

U4DMessageDispatcher::~U4DMessageDispatcher(){
    
}

U4DMessageDispatcher* U4DMessageDispatcher::sharedInstance(){
    
    if (instance==0) {
        
        instance=new U4DMessageDispatcher();
        
    }
    
    return instance;
}


void U4DMessageDispatcher::sendMessage(double uDelay, U4DPlayer *uSenderPlayer, U4DPlayer *uReceiverPlayer, int uMsg){
    
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

void U4DMessageDispatcher::sendMessage(double uDelay, U4DTeam *uTeam, U4DPlayer *uReceiverPlayer, int uMsg){
    
    //if the receiver player is null, then don't send message
    
    if (uReceiverPlayer!=nullptr) {
        //create the message
        Message message;
        
        message.team=uTeam;
        message.receiverPlayer=uReceiverPlayer;
        message.msg=uMsg;
        
        //send the message
        uReceiverPlayer->handleMessage(message);
        
    }
}

void U4DMessageDispatcher::sendMessage(double uDelay, U4DTeam *uReceiverTeam, int uMsg){
    
    //if the receiver team is null, then don't send message
    
//    if (uReceiverTeam!=nullptr) {
//        //create the message
//        Message message;
//
//        message.receiverTeam=uReceiverTeam;
//        message.msg=uMsg;
//
//        //send the message
//        uReceiverTeam->handleMessage(message);
//
//    }
}

void U4DMessageDispatcher::sendMessage(double uDelay, U4DPlayer *uSenderPlayer, U4DPlayer *uReceiverPlayer, int uMsg, void* uExtraInfo){
    
}

}
