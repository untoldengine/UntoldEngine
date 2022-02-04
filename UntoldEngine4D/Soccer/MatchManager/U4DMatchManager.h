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
#include <map>

namespace U4DEngine {

class U4DMatchManager {

private:
    
    static U4DMatchManager *instance;
    
    int teamAScore;
    int teamBScore;
    
    U4DField *field;
    U4DAABB fieldAABB;
    
    U4DGoalPost *teamAGoalPost;
    U4DGoalPost *teamBGoalPost;
    
    int state;
    
    int elapsedClockTime;
    int endClockTime;
    
    U4DCallback<U4DMatchManager> *endGameScheduler;

    //declare the timer
    U4DTimer *endGameTimer;
    
    U4DCallback<U4DMatchManager> *startGameScheduler;

    //declare the timer
    U4DTimer *startGameTimer;
    
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
    
    void initMatchElements(U4DGoalPost *uTeamAGoalPost, U4DGoalPost *uTeamBGoalPost, U4DField *uField);
    
    bool checkIfBallOutOfBounds();
    
    void computeReflectedVelocityForBall(double dt);
    
    void setState(int uState);
    
    int getState();
    
    void changeState(int uState);
    
    U4DGoalPost *getTeamAGoalPost();
    
    U4DGoalPost *getTeamBGoalPost();
    
    void initMatchTimer(int uEndTime, int uFrequency);
    
    void timesUp();
    
    void startGame();
    
    int getElapsedGameTime();
    
    std::vector<int> getCurrentScore();
    
};

}


#endif /* U4DMatchManager_hpp */
