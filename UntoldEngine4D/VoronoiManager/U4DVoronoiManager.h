//
//  U4DVoronoiManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/28/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DVoronoiManager_hpp
#define U4DVoronoiManager_hpp

#include <stdio.h>
#include <vector>
#include <list>
#include <map>
#include "U4DVector2n.h"
#include "U4DVector4n.h"
#include "U4DPlayer.h"
#include "U4DSegment.h"
#include "MyGAL/FortuneAlgorithm.h"
#include "MyGAL/Diagram.h"
#include "MyGAL/Triangulation.h"

namespace U4DEngine {

class U4DVoronoiManager {

private:
    
    mygal::Diagram<double> diagram;
    mygal::Triangulation triangulation;
    static U4DVoronoiManager *instance;
    std::map<int,U4DPlayer*> playerIndexMap;
    
protected:
    
    U4DVoronoiManager();
    
    ~U4DVoronoiManager();
    
public:
    
    static U4DVoronoiManager *sharedInstance();
    
    void computeFortuneAlgorithm();
    
    std::vector<U4DSegment> getVoronoiSegments();
    
    void computeAreas();
    
    float computeSiteArea(int uIndex);
    
    U4DPlayer *getPlayerAtIndex(int uIndex);
    
    std::vector<U4DPlayer*> getNeighbors(int uIndex);
    
    U4DPlayer* getNeighborWithOptimalSpace(int uIndex);
};

}
#endif /* U4DVoronoiManager_hpp */
