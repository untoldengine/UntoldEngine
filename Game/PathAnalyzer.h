//
//  PathAnalyzer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PathAnalyzer_hpp
#define PathAnalyzer_hpp

#include <stdio.h>
#include "U4DNavigation.h"
#include "Player.h"

class PathAnalyzer {
    
private:
    
    static PathAnalyzer *instance;
    
    //Navigation system
    U4DEngine::U4DNavigation *navigationSystem;
    
    std::vector<U4DEngine::U4DSegment> navigationPath;
    
protected:
    
    PathAnalyzer();
    
    ~PathAnalyzer();
    
public:
    
    static PathAnalyzer* sharedInstance();
    
    void computeNavigation(Player *uPlayer);
    
    U4DEngine::U4DVector3n desiredNavigationVelocity();
    
    std::vector<U4DEngine::U4DSegment> getNavigationPath();
    
    void startAnalyzing();
    
};

#endif /* PathAnalyzer_hpp */
