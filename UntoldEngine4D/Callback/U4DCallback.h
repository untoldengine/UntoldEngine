//
//  U4DCallback.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
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
    
    U4DCallback();
    
    void setTimer(U4DTimer *uTimer);
    
    void setClass(T* uClass);
    
    void setMethod(pAction uMethod);
    
    void scheduleClassWithMethodAndDelay(T* uClass, pAction uMethod,U4DTimer* uTimer,bool repeat);
    
    void scheduleClassWithMethodAndDelay(T* uClass, pAction uMethod,U4DTimer* uTimer, double delay,bool repeat);
    
    void scheduleClassWithMethod(T* uClass, pAction uMethod);
    
    void unScheduleTimer(U4DTimer* uTimer);
    
    void action();
    
private:
    T* pClass;
    pAction pMethod;
    U4DTimer *timer;
    
};
    
    template <class T>
    U4DCallback<T>::U4DCallback(){
        pClass=0;
        pMethod=0;
        
    }
    
    template <class T>
    void U4DCallback<T>::setTimer(U4DTimer *uTimer){
        
        timer=uTimer;
    }
    
    template <class T>
    void U4DCallback<T>::setClass(T* uClass){
        
        pClass=uClass;
        
    }
    
    template <class T>
    void U4DCallback<T>::setMethod(pAction uMethod){
        
        pMethod=uMethod;
        
    }
    
    template <class T>
    void U4DCallback<T>::scheduleClassWithMethodAndDelay(T* uClass, pAction uMethod,U4DTimer* uTimer,bool repeat){
        
    }
    
    template <class T>
    void U4DCallback<T>::scheduleClassWithMethodAndDelay(T* uClass, pAction uMethod,U4DTimer* uTimer, double delay,bool repeat)
    {
        pClass=uClass;
        pMethod=uMethod;
        timer=uTimer;
        
        timer->setDelay(delay);
        timer->setRepeat(repeat);
        timer->setCurrentTime(0.0);
        timer->setPause(false);
        
        //register U4DTimer with U4DScheduler
        U4DScheduler *scheduler=U4DScheduler::sharedInstance();
        scheduler->scheduleTimer(timer);
    }
    
    template <class T>
    void U4DCallback<T>::scheduleClassWithMethod(T* uClass, pAction uMethod)
    {
        pClass=uClass;
        pMethod=uMethod;
    }
    
    template <class T>
    void U4DCallback<T>::unScheduleTimer(U4DTimer* uTimer){
        
        //register U4DTimer with U4DScheduler
        U4DScheduler *scheduler=U4DScheduler::sharedInstance();
        scheduler->unscheduleTimer(uTimer);
    }
    
    template <class T>
    void U4DCallback<T>::action(){
        
        (pClass->*pMethod)();
    }

}

#endif /* defined(__UntoldEngine__U4DCallback__) */
