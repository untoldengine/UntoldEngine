//
//  U4DScriptInstanceManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/9/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptInstanceManager_hpp
#define U4DScriptInstanceManager_hpp

#include <stdio.h>
#include <map>
#include <vector>
#include "gravity_value.h"
#include "U4DModel.h"


namespace U4DEngine {

    class U4DScriptInstanceManager {
        
    private:
        
        std::map<uint,gravity_instance_t *> scriptModelInstanceMap;
        std::map<uint, U4DModel*> modelInstanceMap;
        
        static U4DScriptInstanceManager *instance;
        
        
        std::map<U4DAnimation*,gravity_instance_t *> scriptAnimationInstanceMap;

    protected:
        
        U4DScriptInstanceManager();
        
        ~U4DScriptInstanceManager();
        
    public:
        
        static U4DScriptInstanceManager *sharedInstance();
        
        void loadModelScriptInstance(U4DModel *uModel, gravity_instance_t *uGravityInstance);
        
        gravity_instance_t *getModelScriptInstance(uint uEntityID);
        
        bool modelScriptInstanceExist(uint uEntityID);
        
        U4DModel *getModel(uint uEntityID);
        
        void removeModelScriptInstance(uint uEntityID);
        
        void removeAllScriptInstanceModels();
        
    };

}

#endif /* U4DScriptInstanceManager_hpp */
