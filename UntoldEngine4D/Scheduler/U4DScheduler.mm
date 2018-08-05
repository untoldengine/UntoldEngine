//
//  U4DScheduler.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/8/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DScheduler.h"
#include "U4DTimer.h"
#include <string>


namespace U4DEngine {
    
U4DScheduler* U4DScheduler::instance=0;

U4DScheduler* U4DScheduler::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScheduler();
    }
    
    return instance;
}


void U4DScheduler::tick(double dt){
    
    delta=timeScale*dt;
    
    //iterate through all the timers
    for (int i=0; i<timersArray.size(); i++) {
        
        U4DTimer *timer=timersArray.at(i);
        
        timer->tick(delta);
    }
    
}

double U4DScheduler::getTick(){
    
    return delta;
}

void U4DScheduler::scheduleTimer(U4DTimer *uTimer){
    
    //check if the timer exist before adding it
    bool timerPresent=false;
    
    for(auto n:timersArray){
        
        if (n==uTimer) {
            
            timerPresent=true;
        }
        
    }
    
    if (timerPresent==false) {
        
        uTimer->setScheduleTimer(true);
        
        timersArray.push_back(uTimer);
        
    }
    
    
}

void U4DScheduler::unscheduleTimer(U4DTimer *uTimer){
    
    //get timer index to remove
    uTimer->setScheduleTimer(false);
    
    //remove the timer
    timersArray.erase(std::remove_if(timersArray.begin(),timersArray.end(),[](U4DTimer *timerToRemove){return timerToRemove->getScheduleTimer()==false;}),timersArray.end());
    
}

void U4DScheduler::unscheduleAllTimers(){
    
    timersArray.clear();
}

}
