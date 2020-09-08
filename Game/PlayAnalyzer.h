//
//  PlayAnalyzer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayAnalyzer_hpp
#define PlayAnalyzer_hpp

#include <stdio.h>

class Player;

class PlayAnalyzer {
    
private:

    static PlayAnalyzer* instance;
    
protected:
    
    PlayAnalyzer();
    
    ~PlayAnalyzer();
    
public:
    
    static PlayAnalyzer* sharedInstance();

    Player *closestTeammateToIntersectBall(Player *uPlayer);
    
};

#endif /* PlayAnalyzer_hpp */
