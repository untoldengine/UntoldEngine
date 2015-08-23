//
//  U4DCallback.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DCallback__
#define __UntoldEngine__U4DCallback__

#include <iostream>
#include "U4DCallbackInterface.h"
#include "U4DTimer.h"
#include "U4DScheduler.h"

namespace U4DEngine {
class U4DTimer;
class U4DScheduler;
}

namespace U4DEngine {
    
template <class T>
class U4DCallback:public U4DCallbackInterface{

public:
        
    typedef void (T::*pAction)();
    
    U4DCallback(){
        pClass=0;
        pMethod=0;
        
    };
    
    inline void setTimer(U4DTimer *uTimer){
        
        timer=uTimer;
    }
    
    inline void setClass(T* uClass){
        
        pClass=uClass;
        
    }
    
    inline void setMethod(pAction uMethod){
        
        pMethod=uMethod;
        
    }
    
    inline void scheduleClassWithMethodAndDelay(T* uClass, pAction uMethod,U4DTimer* uTimer,bool repeat){
        
    }
    
    inline void scheduleClassWithMethodAndDelay(T* uClass, pAction uMethod,U4DTimer* uTimer, double delay,bool repeat)
    {
        pClass=uClass;
        pMethod=uMethod;
        timer=uTimer;
        
        timer->setDelay(delay);
        timer->setRepeat(repeat);
        
        //register U4DTimer with U4DScheduler
        U4DScheduler *scheduler=U4DScheduler::sharedInstance();
        scheduler->scheduleTimer(timer);
    }
    
    inline void scheduleClassWithMethod(T* uClass, pAction uMethod)
    {
        pClass=uClass;
        pMethod=uMethod;
    }
    
    inline void unScheduleTimer(U4DTimer* uTimer){
        
        //register U4DTimer with U4DScheduler
        U4DScheduler *scheduler=U4DScheduler::sharedInstance();
        scheduler->unscheduleTimer(uTimer);
    }
    
    
    inline void action(){
        
        (pClass->*pMethod)();
    }

private:
    T* pClass;
    pAction pMethod;
    U4DTimer *timer;
    
};

}

#endif /* defined(__UntoldEngine__U4DCallback__) */
