//
//  U4DLayerManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DLayerManager.h"
#include "U4DControllerInterface.h"
#include "U4DWorld.h"
#include "U4DLayer.h"

namespace U4DEngine {

    U4DLayerManager* U4DLayerManager::instance=0;

    U4DLayerManager::U4DLayerManager(){
        
    }
        
    U4DLayerManager::~U4DLayerManager(){
        
    }

    U4DLayerManager* U4DLayerManager::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DLayerManager();
            
        }
        
        return instance;
    }

    void U4DLayerManager::setController(U4DControllerInterface *uController){
        controller=uController;
    }

    void U4DLayerManager::setWorld(U4DWorld *uWorld){
        world=uWorld;
    }

    void U4DLayerManager::addLayerToContainer(U4DLayer* uLayer){
        
        layerContainer.push_back(uLayer);
        
    }
        
    void U4DLayerManager::pushLayer(std::string uLayerName){
        
        for(const auto &n:layerContainer){
            
            if (n->getName().compare(uLayerName)==0) {
                
                //add the layer to the view(U4DWorld) component scenegraph
                world->addChild(n,0);
                
                //push the layer into the stack
                layerStack.push(n);

                break;
                
            }
            
        }
        
        
    }
        
        
    void U4DLayerManager::popLayer(){
        
        //remove the layer from the view(U4DWorld) component scenegraph along with its children
        if(!layerStack.empty()){
         
            //Get a pointer to the top most layer
            U4DLayer *topLayer=layerStack.top();
            
            world->removeChild(topLayer);
            
            //pop the layer from the stack
            layerStack.pop();
            
        }
        
    }

    U4DLayer *U4DLayerManager::getActiveLayer(){
        
        U4DLayer *topLayer=nullptr;
        
        if(!layerStack.empty()){
            
            topLayer=layerStack.top();
            
        }

        return topLayer;
        
    }

}
