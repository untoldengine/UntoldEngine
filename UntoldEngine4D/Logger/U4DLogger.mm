//
//  U4DLogger.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/7/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#include "U4DLogger.h"

namespace U4DEngine {

    U4DLogger* U4DLogger::instance=0;
    
    U4DLogger::U4DLogger():debugMode(true){
    }
    
    U4DLogger::~U4DLogger(){
        
    }

    U4DLogger* U4DLogger::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DLogger();
        }

        return instance;
    }
    
    void U4DLogger::log(const char* uLog, ...){
        
        if (debugMode==true) {

//START ORIGINAL LOGGER
//            char buffer[1024];
//            va_list args;
//            va_start (args, uLog);
//            vsprintf (buffer,uLog, args);
//
//            logBuffer.push_back(buffer);
//            std::cout<<buffer<<std::endl;
//
//            va_end (args);
//END ORIGINAL LOGGER
            
            int old_size = logBuffer.size();
            va_list args;
            va_start(args, uLog);
            logBuffer.appendfv(uLog, args);
            va_end(args);
            logBuffer.append("\n");
            for (int new_size = logBuffer.size(); old_size < new_size; old_size++)
                if (logBuffer[old_size] == '\n')
                    LineOffsets.push_back(old_size + 1);
        
        }
    }
    
    void U4DLogger::setDebugMode(bool uValue){
        debugMode=uValue;
    }
    
}
