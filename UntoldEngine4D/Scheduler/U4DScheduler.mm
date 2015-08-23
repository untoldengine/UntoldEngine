//
//  U4DScheduler.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/8/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
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
    
    timersArray.push_back(uTimer);
    
    //set the timer index
    for (int i=0; i<timersArray.size(); i++) {
    
        U4DTimer *timer=timersArray.at(i);
        timer->setIndex(i);
    
    }
}

void U4DScheduler::unscheduleTimer(U4DTimer *uTimer){
    
    //remove the timer
    timersArray.erase(timersArray.begin()+uTimer->getIndex());
    
    //update the timer index
    for (int i=0; i<timersArray.size(); i++) {
        
        U4DTimer *timer=timersArray.at(i);
        timer->setIndex(i);
    }
}

void U4DScheduler::unscheduleAllTimers(){
    
    timersArray.clear();
}

}