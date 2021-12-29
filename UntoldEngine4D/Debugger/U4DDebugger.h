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
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DAABB.h"

namespace U4DEngine {

    class U4DDebugger {
        
    private:
        
        U4DCallback<U4DDebugger> *scheduler;
        
        U4DTimer *timer;
        
        U4DText *consoleLabel;

        U4DText *profilerLabel;
        
        U4DText *serverConnectionLabel;
        
        static U4DDebugger* instance;
        
        bool enableDebugger;
        
        bool uiLoaded;
        
        bool enableShaderReload;
        
        std::string pipelineToReload;
        std::string shaderFilePath;
        std::string vertexShaderName;
        std::string fragmentShaderName;
        
    protected:
        
        U4DDebugger();
        
        ~U4DDebugger();
        
    public:
        U4DWorld *world;
        
        
        static U4DDebugger* sharedInstance();
        
        std::string getEntitiesInScenegraph();
        
        void runDebugger();
        
        void setEnableDebugger(bool uValue, U4DWorld *uWorld);
        
        bool getEnableDebugger();
        
        void reloadShader(std::string uPipelineToReload, std::string uFilepath, std::string uVertexShader, std::string uFragmentShader);
        
    };

}


#endif /* U4DDebugger_hpp */
