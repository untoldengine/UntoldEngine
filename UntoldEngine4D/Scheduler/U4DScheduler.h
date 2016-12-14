//
//  U4DScheduler.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/8/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DScheduler__
#define __UntoldEngine__U4DScheduler__

#include <iostream>
#include <vector>

namespace U4DEngine {
class U4DTimer;
}

namespace U4DEngine {
    
class U4DScheduler{
  
private:
    
    static U4DScheduler* instance;
    std::vector<U4DTimer*> timersArray;
    
    double timeScale;
    double delta;
    int timerIndex;
    
protected:
    
    U4DScheduler():timeScale(1.0),delta(0.0),timerIndex(0){};
    
    ~U4DScheduler(){};
    
public:
    static U4DScheduler* sharedInstance();
    
    void tick(double dt);
    double getTick();
    void scheduleTimer(U4DTimer *uTimer);
    void unscheduleTimer(U4DTimer *timer);
    void unscheduleAllTimers();
};

}

#endif /* defined(__UntoldEngine__U4DScheduler__) */
