//
//  U4DPathAnalyzer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPathAnalyzer_hpp
#define U4DPathAnalyzer_hpp

#include <stdio.h>
#include "U4DNavigation.h"
#include "U4DPlayer.h"

namespace U4DEngine {

class U4DPathAnalyzer {
    
private:
    
    static U4DPathAnalyzer *instance;
    
    //Navigation system
    U4DNavigation *navigationSystem;
    
    std::vector<U4DSegment> navigationPath;
    
protected:
    
    U4DPathAnalyzer();
    
    ~U4DPathAnalyzer();
    
public:
    
    static U4DPathAnalyzer* sharedInstance();
    
    void computeNavigation(U4DPlayer *uPlayer);
    
    U4DVector3n desiredNavigationVelocity(U4DPlayer *uPlayer);
    
    std::vector<U4DSegment> getNavigationPath();
    
    void startAnalyzing();
    
};

}

#endif /* U4DPathAnalyzer_hpp */
