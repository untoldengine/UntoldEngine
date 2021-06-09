//
//  U4DProfilerManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DProfilerManager_hpp
#define U4DProfilerManager_hpp

#include <stdio.h>
#include <string>
#include <iostream>

#include "U4DProfilerNode.h"


namespace U4DEngine {

    class U4DProfilerManager {
        
    private:
    
        U4DProfilerNode *rootNode;
        
        U4DProfilerNode *currentNode;
        
        static U4DProfilerManager *instance;
        
        bool enableProfiler;
        
    protected:
        
        U4DProfilerManager();
        
        ~U4DProfilerManager();
        
    public:
        
        static U4DProfilerManager *sharedInstance();
        
        U4DProfilerNode *searchProfilerNode(std::string uNodeName);
        
        void startProfiling(std::string uNodeName);
        
        void stopProfiling();
        
        std::string getProfileLog();
        
        void setEnableProfiler(bool uValue);
        
    };

}



#endif /* U4DProfilerManager_hpp */
