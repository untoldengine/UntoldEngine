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

namespace U4DEngine {
    
    class U4DLogger {
        
    private:
        
    protected:
        
        /**
         *  Logger Constructor
         */
        U4DLogger();
        
        /**
         *  Logger Destructor
         */
        ~U4DLogger();
        
        /**
         *  Copy constructor
         */
        U4DLogger(const U4DLogger& value);
        
        /**
         *  Copy constructor
         */
        U4DLogger& operator=(const U4DLogger& value);
        
    public:
        
        /**
         *  Instance for U4DLogger Singleton
         */
        static U4DLogger* instance;
        
        /**
         *  SharedInstance for U4DLogger Singleton
         */
        static U4DLogger* sharedInstance();
        
        void log(const char* uLog);
        
    };

}

#endif /* U4DLogger_hpp */
