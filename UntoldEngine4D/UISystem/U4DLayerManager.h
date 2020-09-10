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

    /**
    @ingroup scene
    @brief The U4DLayerManager class manages the layer objects currently present in the scene. Layers are object that can be rendered on top of the view component.
    */
    class U4DLayerManager {
        
    private:
                
        /**
         @brief pointer to the controller
         */
        U4DControllerInterface *controller;
        
        /**
         @brief pointer to the world
         */
        U4DWorld *world;
        
        /**
         @brief stack layer data structure
         */
        std::stack<U4DLayer*> layerStack;
        
        /**
         @brief single instance for the layer manager
         */
        static U4DLayerManager* instance;
        
        /**
         @brief Layer container
         */
        std::vector<U4DLayer*> layerContainer;
        
    protected:
        
        /**
         @brief Constructor
         */
        U4DLayerManager();
        
        /**
         @brief Destructor
         */
        ~U4DLayerManager();
        
    public:
        
        /**
         @brief returns the instance of the singleton
         */
        static U4DLayerManager* sharedInstance();
        
        /**
         @brief sets the active controller
         @param uController current active controller in the game
         */
        void setController(U4DControllerInterface *uController);
        
        /**
         @brief sets the current active view component
         @param uWorld view Component
         */
        void setWorld(U4DWorld *uWorld);
        
        /**
         @brief adds layer to the layer-container
         @param uLayer layer to add
         */
        void addLayerToContainer(U4DLayer* uLayer);
        
        /**
         @brief pushes a new layer into the stack
         @param uLayerName name of the layer to push onto the stack
         */
        void pushLayer(std::string uLayerName);
        
        /**
         @brief pops the top layer from the stack
         */
        void popLayer();
        
        /**
         @brief returs the active layer
         */
        U4DLayer *getActiveLayer();
        
        /**
         @brief clears the layer container and stack
         */
        void clear();
        
    };

}

#endif /* U4DLayerManager_hpp */
