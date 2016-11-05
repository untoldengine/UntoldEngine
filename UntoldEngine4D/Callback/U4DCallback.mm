//
//  U4DCallback.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DCallback__CPP
#define __UntoldEngine__U4DCallback__CPP

#include "U4DCallback.h"

namespace U4DEngine {
    
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

#endif



