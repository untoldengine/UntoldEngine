//
//  U4DGameConfigs.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/5/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DGameConfigs_hpp
#define U4DGameConfigs_hpp

#include <stdio.h>
#include <string>
#include <map>

namespace U4DEngine {

    class U4DGameConfigs {
        
    private:
        
        static U4DGameConfigs *instance;
        
    protected:
        
        U4DGameConfigs();
        
        ~U4DGameConfigs();
        
    public:
        
        std::map<std::string,float> configsMap;
        
        static U4DGameConfigs* sharedInstance();
        
        void initConfigsMapKeys(const char* uConfigName,...);
        
        float getParameterForKey(std::string uName);
        
        void loadConfigsMapValues(std::string uFileName);
        
        void clearConfigsMap();
        
    };

}


#endif /* U4DGameConfigs_hpp */
