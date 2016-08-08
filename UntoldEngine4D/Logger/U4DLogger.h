//
//  U4DLogger.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DLogger_hpp
#define U4DLogger_hpp

#include <stdio.h>
#include <iostream>
#include <string>

namespace U4DEngine {
    
    class U4DLogger {
        
    private:
        
        bool debugMode;
        bool engineMode;
        
    protected:
        
        /**
         *  Logger Constructor
         */
        U4DLogger();
        
        /**
         *  Copy constructor
         */
        U4DLogger(const U4DLogger& value);
        
        /**
         *  Copy constructor
         */
        U4DLogger& operator=(const U4DLogger& value);
        
        /**
         *  Logger Destructor
         */
        ~U4DLogger();
        
    public:
        
        /**
         *  Instance for U4DLogger Singleton
         */
        static U4DLogger* instance;
        
        /**
         *  SharedInstance for U4DLogger Singleton
         */
        static U4DLogger* sharedInstance();

        void log(const char* uLog, ...);
        
        void engineLog(const char* uLog, ...);
        
        void setDebugMode(bool uValue);
        
        void setEngineMode(bool uValue);
        
    };

}

#endif /* U4DLogger_hpp */
