//
//  U4DLayerManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DLayerManager_hpp
#define U4DLayerManager_hpp

#include <stdio.h>
#include <string>
#include <stack>
#include <vector>

namespace U4DEngine {

    class U4DLayer;
    class U4DControllerInterface;
    class U4DWorld;

}

namespace U4DEngine {

    class U4DLayerManager {
        
    private:
                
        //pointer to the controller
        U4DControllerInterface *controller;
        
        //pointer to the world
        U4DWorld *world;
        
        //stack layer data structure
        std::stack<U4DLayer*> layerStack;
        
        static U4DLayerManager* instance;
        
        //Layer container
        std::vector<U4DLayer*> layerContainer;
        
    protected:
        
        U4DLayerManager();
        
        ~U4DLayerManager();
        
    public:
        
        static U4DLayerManager* sharedInstance();
        
        void setController(U4DControllerInterface *uController);
        
        void setWorld(U4DWorld *uWorld);
        
        void addLayerToContainer(U4DLayer* uLayer);
        
        void pushLayer(std::string uLayerName);
        
        void popLayer();
        
        U4DLayer *getActiveLayer();
        
        void clear();
        
    };

}

#endif /* U4DLayerManager_hpp */
