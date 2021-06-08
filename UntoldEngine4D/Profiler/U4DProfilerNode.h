//
//  U4DProfilerNode.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DProfilerNode_hpp
#define U4DProfilerNode_hpp

#include <stdio.h>
#include <chrono>
#include <string>

namespace U4DEngine {

    class U4DProfilerNode {
        
    private:
        
        std::string name;
        
        //start time
        std::chrono::steady_clock::time_point startTime;
        //end time
        
        //total time
        float totalTime;
        
        float timeAccumulator;
        
    public:
        
        U4DProfilerNode(std::string uNodeName);
        
        ~U4DProfilerNode();
        
        void startProfiling();
        
        void stopProfiling();
        
        float getTotalTime();
        
        std::string getName();
        
    };

}

#endif /* U4DProfilerNode_hpp */
