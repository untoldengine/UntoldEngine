//
//  U4DScriptInstanceManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DScriptDictionary_hpp
#define U4DScriptDictionary_hpp

#include <stdio.h>
#include <map>
#include <vector>
#include "gravity_value.h"
#include "U4DModel.h"
#include "U4DAnimation.h"
#include "U4DAnimationManager.h"
#include "U4DDynamicAction.h"

namespace U4DEngine {

    class U4DScriptInstanceManager {
        
    private:
        
        std::map<int,gravity_instance_t *> scriptModelInstanceMap;
        
        static U4DScriptInstanceManager *instance;
        
        int modelInstanceIndex;
        
        std::map<U4DAnimation*,gravity_instance_t *> scriptAnimationInstanceMap;
        std::map<U4DAnimationManager*,gravity_instance_t *> scriptAnimManagerInstanceMap;
        std::map<U4DDynamicAction*,gravity_instance_t *> scriptDynamicActionInstanceMap;
        
    protected:
        
        U4DScriptInstanceManager();
        
        ~U4DScriptInstanceManager();
        
    public:
        
        static U4DScriptInstanceManager *sharedInstance();
        
        void loadModelScriptInstance(U4DModel *uModel, gravity_instance_t *uGravityInstance);
        
        gravity_instance_t *getModelScriptInstance(int uScriptID);
        
        bool modelScriptInstanceExist(int uScriptID);
        
        void removeModelScriptInstance(int uScriptID);
        
        
        void loadAnimationScriptInstance(U4DAnimation *uAnimation, gravity_instance_t *uGravityInstance);
        
        gravity_instance_t *getAnimationScriptInstance(U4DAnimation *uAnimation);
        
        void loadDynamicActionScriptInstance(U4DDynamicAction *uDynamicAction, gravity_instance_t *uGravityInstance);
        
        gravity_instance_t *getDynamicActionScriptInstance(U4DDynamicAction *uDynamicAction);
        
        void loadAnimManagerScriptInstance(U4DAnimationManager *uAnimationManager, gravity_instance_t *uGravityInstance);
        
        gravity_instance_t *getAnimManagerScriptInstance(U4DAnimationManager *uAnimationManager);
        
        
        void removeAllScriptInstanceModels();
        void removeAllScriptInstanceAnimations();
        void removeAllScriptInstanceDynamicActions();
        void removeAllScriptInstanceAnimManagers();
        
        void removeAllScriptInstances();
        
    };

}


#endif /* U4DScriptDictionary_hpp */
