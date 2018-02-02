//
//  U4DTimer.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DTimer__
#define __UntoldEngine__U4DTimer__

#include <iostream>
#include "U4DCallbackInterface.h"

namespace U4DEngine {
    
class U4DTimer{
  
private:
    U4DCallbackInterface *pCallback;
    
    bool repeat;
    
    double delay;
    
    double currentTime;

    bool pause;
    
    bool scheduleTimer;
    
public:
    
    //constructor
    U4DTimer():currentTime(0.0),repeat(false),delay(0.0),pause(false),scheduleTimer(false){};
    
    U4DTimer(U4DCallbackInterface *uPCallback):currentTime(0.0),repeat(false),delay(0.0),pCallback(uPCallback){};
    
    //desctructor
    ~U4DTimer(){};
    
    void initCallback(U4DCallbackInterface *uPCallback){
        pCallback=uPCallback;
    }
    
    void timerExpire(); //called when the timer has reached duration
    
    void tick(double dt);
    
    void setDelay(double uDelay);
    
    double getDelay() const;
    
    void setRepeat(bool uRepeat);
    
    void setPause(bool uValue);
    
    bool getPause();
    
    void setScheduleTimer(bool uValue);
    
    bool getScheduleTimer();
    
    void setCurrentTime(float uValue);
    
};

}

#endif /* defined(__UntoldEngine__U4DTimer__) */
