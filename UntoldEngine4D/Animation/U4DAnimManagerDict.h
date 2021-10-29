//
//  U4DAnimManagerDict.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/20/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DAnimManagerDictionary_hpp
#define U4DAnimManagerDictionary_hpp

#include <stdio.h>
#include <string>
#include "U4DAnimationManager.h"

namespace U4DEngine {

    class U4DAnimManagerDict {

    private:
        
        static U4DAnimManagerDict* instance;
        
        std::map<std::string,U4DAnimationManager*> animationManagerMap;
        
    protected:
        
        U4DAnimManagerDict();
        
        ~U4DAnimManagerDict();
        
    public:
        
        static U4DAnimManagerDict* sharedInstance();
        
        void loadAnimManagerDictionary(std::string uName, U4DAnimationManager *uAnimationManager);
        
        U4DAnimationManager * getAnimManager(std::string uName);
        
        void removeAnimManager(std::string uName);
        
        void updateAnimManagerDictionary(std::string uOriginalName, std::string uNewName);
        
    }; 

}
#endif /* U4DAnimManagerDictionary_hpp */
