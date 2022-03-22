//
//  U4DPlayAnalyzer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlayAnalyzer_hpp
#define U4DPlayAnalyzer_hpp

#include <stdio.h>

namespace U4DEngine {

class U4DPlayer;
class U4DTeam;
 
    class U4DPlayAnalyzer {
        
    private:

        static U4DPlayAnalyzer* instance;
        
    protected:
        
        U4DPlayAnalyzer();
        
        ~U4DPlayAnalyzer();
        
    public:
        
        static U4DPlayAnalyzer* sharedInstance();

        U4DPlayer *closestTeammateToIntersectBall(U4DPlayer *uPlayer);
        
        U4DPlayer *closestTeammateToIntersectBall(U4DTeam *uTeam);
        
        void analyzeActionToMake();
        
    };

}

#endif /* U4DPlayAnalyzer_hpp */
