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
    
    /**
     @brief The U4DLogger class implements messages notifications sent to the console log window
     */
    class U4DLogger {
        
    private:
        
        /**
         @brief If set to true, the logger prints notifications to the console window.
         */
        bool debugMode;
        
    protected:
        
        /**
         @brief Constructor for the Logger
         */
        U4DLogger();
        
        /**
         @brief Destructor for the Logger
         */
        ~U4DLogger();
        
    public:
        
        /**
         @brief Instance for the U4DLogger Singleton
         */
        static U4DLogger* instance;

        /**
         @brief Method which returns a instance of the U4DLogger Singleton
         
         @return Returns an instance of the U4DLogger
         */
        static U4DLogger* sharedInstance();

        /**
         @brief Method which prints notifications to the console log window
         
         @param uLog Message to print
         @param ...  Message to print
         */
        void log(const char* uLog, ...);
        
        /**
         @brief Method which enables printing to the console window
         
         @param uValue Boolean value which enables printint to the console
         */
        void setDebugMode(bool uValue);
        
    };

}

#endif /* U4DLogger_hpp */
