//
//  U4DDebugger.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/4/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DDebugger_hpp
#define U4DDebugger_hpp

#include <stdio.h>
#include <string>
#include "U4DEntity.h"
#include "U4DWorld.h"
#include "U4DText.h"
#include "U4DCheckbox.h"
#include "U4DSlider.h"
#include "U4DBoundingBVH.h"

namespace U4DEngine {

    class U4DDebugger {
        
    private:
        
        U4DWorld *world;
        
        U4DText *consoleLabel;
                
        U4DText *profilerLabel;
        
        U4DCheckbox *checkboxShowBVH;
        
        U4DCheckbox *checkboxShowNarrowPhaseVolume;
        
        U4DCheckbox *checkboxShowBroadPhaseVolume;
        
        U4DCheckbox *checkboxShowProfiler;
        
        U4DBoundingBVH *bvhTree;
        
        static U4DDebugger* instance;
        
        bool enableDebugger;
        
        bool showBVHTree;
        
        bool uiLoaded;
        
    protected:
        
        U4DDebugger();
        
        ~U4DDebugger();
        
    public:
        
        static U4DDebugger* sharedInstance();
        
        std::string getEntitiesInScenegraph();
        
        void update(double dt);
        
        void setEnableDebugger(bool uValue, U4DWorld *uWorld);
        
        bool getShowBVHTree();
        
        void loadBVHTreeData(std::vector<U4DPoint3n> &uMin, std::vector<U4DPoint3n> &uMax);
        
        bool getEnableDebugger();
        
        void actionCheckboxShowBVH();
        
        void actionCheckboxShowBroadPhaseVolume();
        
        void actionCheckboxShowNarrowPhaseVolume();
        
        void actionCheckboxShowProfiler();
        
    };

}


#endif /* U4DDebugger_hpp */
