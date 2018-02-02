//
//  U4DTimer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DTimer.h"
#include "U4DScheduler.h"

namespace U4DEngine {
    
void U4DTimer::tick(double dt){
    
    if (getPause()==false) {
        
        currentTime=currentTime+dt;
        
        if (currentTime>=delay) {
            
            timerExpire();
            
        }
        
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
    
void U4DTimer::setDelay(double uDelay){
    delay=uDelay;
}

double U4DTimer::getDelay() const{
    return delay;
}

void U4DTimer::setRepeat(bool uRepeat){
    repeat=uRepeat;
}
    
void U4DTimer::setPause(bool uValue){
    pause=uValue;
}

bool U4DTimer::getPause(){
    return pause;
}
    
void U4DTimer::setScheduleTimer(bool uValue){
    
    scheduleTimer=uValue;
}
    
bool U4DTimer::getScheduleTimer(){
    
    return scheduleTimer;
}
    
void U4DTimer::setCurrentTime(float uValue){
    
    currentTime=uValue;
    
}

}
