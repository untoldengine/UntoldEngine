//
//  U4DMatchManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/14/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMatchManager_hpp
#define U4DMatchManager_hpp

#include <stdio.h>
#include "U4DTeam.h"
#include "U4DAABB.h"
#include "U4DField.h"
#include "U4DGoalPost.h"
#include "U4DText.h"
#include "U4DWorld.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

namespace U4DEngine {

class U4DMatchManager {

private:
    
    static U4DMatchManager *instance;
    
    float fieldHalfWidth;
    float fieldHalfLength;
    U4DField *field;
    U4DAABB fieldAABB;
    
    U4DGoalPost *goalPost0;
    U4DGoalPost *goalPost1;
    
    int state;
    
    U4DText *gameClock;
    
    int clockTime;
    int endClockTime;
    
    U4DWorld *world;
    
    U4DCallback<U4DMatchManager> *timeUpScheduler;

    //declare the timer
    U4DTimer *timeUpTimer;
    
protected:
    
    U4DMatchManager();
    
    ~U4DMatchManager();
    
public:
    
    U4DTeam *teamA;
    U4DTeam *teamB;
    
    //bool goalScored;
    bool ballOutOfBound;
    
    static U4DMatchManager *sharedInstance();
    
    void update(double dt);
    
    void initMatch(U4DWorld *uWorld, U4DGoalPost *uGoalPost0, U4DGoalPost *uGoalPost1, U4DField *uField);
    
    bool checkIfBallOutOfBounds();
    
    void computeReflectedVelocityForBall(double dt);
    
    void setState(int uState);
    
    int getState();
    
    void changeState(int uState);
    
    U4DGoalPost *getTeamAGoalPost();
    
    U4DGoalPost *getTeamBGoalPost();
    
    void initMatchTimer(int uInitTime, int uEndTime, int uFrequency, U4DVector2n uPosition, std::string uFontName);
    
    void timesUp();
    
};

}


#endif /* U4DMatchManager_hpp */
