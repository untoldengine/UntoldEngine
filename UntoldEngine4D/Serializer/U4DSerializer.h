//
//  U4DSerializer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/1/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSerializer_hpp
#define U4DSerializer_hpp

#include <stdio.h>
#include <string>
#include <vector>
#include "CommonProtocols.h"
#include "U4DSceneConfig.h"
#include "tinyxml2.h"

namespace U4DEngine {

    class U4DSerializer {

    private:
        
        static U4DSerializer *instance;
        
        std::string filename;
        
    protected:
        
        U4DSerializer();
        
        ~U4DSerializer();
        
    public:
        
        tinyxml2::XMLDocument xmlDoc;
        
        static U4DSerializer *sharedInstance();
        
        bool serialize(std::string uFileName);
        
        bool deserialize(std::string uFileName);
        
        void setupScene();
        
        std::string getFileName();
        
        
    };

}
#endif /* U4DSerializer_hpp */
