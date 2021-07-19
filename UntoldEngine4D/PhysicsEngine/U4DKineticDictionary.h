//
//  U4DKineticDictionary.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DKineticManager_hpp
#define U4DKineticManager_hpp

#include <stdio.h>
#include <map>
#include <string>
#include "U4DDynamicAction.h"

namespace U4DEngine {

    /**
     @ingroup physicsengine
     @brief The U4DKineticDictionary class is a dictionary for all actions currently active
     */
    class U4DKineticDictionary {

    private:
        
        /**
         @brief Instace for the U4DKineticDictionary singleton
         */
        static U4DKineticDictionary* instance;
        
        std::map<std::string,U4DDynamicAction*> kineticBehaviorMap;
        
    protected:
        
        U4DKineticDictionary();
        
        ~U4DKineticDictionary();
        
    public:
        
        /**
         @brief Method which returns an instace of the U4DKineticDictionary singleton
         
         @return instance of the U4DKineticDictionary singleton
         */
        static U4DKineticDictionary* sharedInstance();
        
        void loadBehaviorDictionary(std::string uName, U4DDynamicAction *uDynamicModel);
        
        U4DDynamicAction * getKineticBehavior(std::string uName);
        
        void removeKineticBehavior(std::string uName);
        
        void updateKineticBehaviorDictionary(std::string uOriginalName, std::string uNewName);
    };

}

#endif /* U4DKineticManager_hpp */
