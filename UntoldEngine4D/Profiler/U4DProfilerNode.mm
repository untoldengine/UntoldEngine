//
//  U4DProfilerNode.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DProfilerNode.h"
#include "U4DLogger.h"

namespace U4DEngine {

    U4DProfilerNode::U4DProfilerNode(std::string uNodeName):timeAccumulator(0.0),name(uNodeName){
    
    }
        
    U4DProfilerNode::~U4DProfilerNode(){
        
    }

    void U4DProfilerNode::startProfiling(){
        
        //start the time
        startTime=std::chrono::steady_clock::now();
    }
        
    void U4DProfilerNode::stopProfiling(){
        
        std::chrono::steady_clock::time_point endTime = std::chrono::steady_clock::now();
        
        totalTime=std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime).count();
        
        //smooth out the value by using a Recency Weighted Average.
        //The RWA keeps an average of the last few values, with more recent values being more
        //significant. The bias parameter controls how much significance is given to previous values.
        //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
        //A bias of 1 ignores the new value altogether.
        float biasMotionAccumulator=0.9;
        
        timeAccumulator=timeAccumulator*biasMotionAccumulator+totalTime*(1.0-biasMotionAccumulator);
        
        totalTime=timeAccumulator;
    
    }

    float U4DProfilerNode::getTotalTime(){
        
        return totalTime;
        
    }

    std::string U4DProfilerNode::getName(){
        return name;
    }

}
