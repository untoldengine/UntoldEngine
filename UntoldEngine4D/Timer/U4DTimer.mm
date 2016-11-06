//
//  U4DTimer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DTimer.h"
#include "U4DScheduler.h"

namespace U4DEngine {
    
void U4DTimer::tick(double dt){
    
    currentTime=currentTime+dt;
    
    if (currentTime>=delay) {
        
        timerExpire();
        hasTimerExpired=true;
    }else{

            hasTimerExpired=false;
    }

}

void U4DTimer::timerExpire(){
    
    pCallback->action();  //call the callback method
    
    if (repeat==true) {
        
        currentTime=0;
        
    }else if(repeat==false){
        
        //remove timer from scheduler
        U4DScheduler *scheduler=U4DScheduler::sharedInstance();
        scheduler->unscheduleTimer(this);
    }
    
}
    
bool U4DTimer::getHasTimerExpired(){
    return hasTimerExpired;
}
    
void U4DTimer::setIndex(int uIndex){
    index=uIndex;
}

int U4DTimer::getIndex(){
    return index;
}

void U4DTimer::setDelay(double uDelay){
    delay=uDelay;
}

double U4DTimer::getDelay() const{
    return delay;
}

void U4DTimer::setRepeat(bool uRepeat){
    repeat=uRepeat;
}

}
