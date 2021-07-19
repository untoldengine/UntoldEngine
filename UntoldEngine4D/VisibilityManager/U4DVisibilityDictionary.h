//
//  U4DVisibilityDictionary.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DVisibilityDictionary_hpp
#define U4DVisibilityDictionary_hpp

#include <stdio.h>
#include <map>
#include <string>
#include "U4DModel.h"

namespace U4DEngine {

    /**
     @ingroup camera
     @brief The U4DVisibilityDictionary class is a dictionary that keeps tracks of all visible 3D models
     */
    class U4DVisibilityDictionary {

    private:
        
        /**
         @brief Instace for the U4DVisibilityDictionary singleton
         */
        static U4DVisibilityDictionary* instance;
        
        std::map<std::string,U4DModel*> visibilityMap;
        
    protected:
        
        U4DVisibilityDictionary();
        
        ~U4DVisibilityDictionary();
        
    public:
        
        /**
         @brief Method which returns an instace of the U4DVisibilityDictionary singleton
         
         @return instance of the U4DVisibilityDictionary singleton
         */
        static U4DVisibilityDictionary* sharedInstance();
        
        void loadIntoVisibilityDictionary(std::string uName, U4DModel *uModel);
        
        U4DModel * getVisibleModel(std::string uName);
        
        void removeFromVisibilityDictionary(std::string uName);
        
        void updateVisibilityDictionary(std::string uOriginalName, std::string uNewName);
        
    };

}
#endif /* U4DVisibilityDictionary_hpp */
