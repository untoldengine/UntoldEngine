//
//  U4DProfilerManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DProfilerManager.h"


namespace U4DEngine {

    U4DProfilerManager *U4DProfilerManager::instance=0;

    U4DProfilerManager *U4DProfilerManager::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DProfilerManager();
        }
        
        return instance;
        
    }

    U4DProfilerManager::U4DProfilerManager():enableProfiler(false){
        
        rootNode=new U4DNode<U4DProfilerNode>("root"); 
        currentNode=rootNode;
    }
        
    U4DProfilerManager::~U4DProfilerManager(){
        
        delete rootNode;
        
    }

    U4DNode<U4DProfilerNode> *U4DProfilerManager::searchProfilerNode(std::string uNodeName){
        
        //child node was found
        U4DNode<U4DProfilerNode>* profilerNode=rootNode->searchChild(uNodeName);
            
        //child node was not found, then create it
        if (profilerNode==nullptr) {
            profilerNode=new U4DNode<U4DProfilerNode>(uNodeName);
            currentNode->addChild(profilerNode);
        }
        
        return profilerNode;
            
    }

    void U4DProfilerManager::startProfiling(std::string uNodeName){
        
        if (enableProfiler==true && currentNode!=nullptr) {
            
            if (currentNode->getName()!=uNodeName) {
                currentNode=searchProfilerNode(uNodeName);
            }
            
            currentNode->startProfiling();
            
        }
        
    }

    void U4DProfilerManager::stopProfiling(){
        
        if (enableProfiler==true && currentNode!=nullptr) {
            
            currentNode->stopProfiling();
            currentNode=currentNode->getParent(); 
            
        }
        
    }

    void U4DProfilerManager::setEnableProfiler(bool uValue){
        
        enableProfiler=uValue;
    }
        
    std::string U4DProfilerManager::getProfileLog(){
        
        std::string profilerLog;
        
        U4DNode<U4DProfilerNode> *child=rootNode->next;
        
        while(child!=nullptr){
            
            profilerLog=profilerLog+child->getName()+": "+ std::to_string(child->getTotalTime()) + " usecs\n ";
            
            child=child->next;
        }
        
        return profilerLog;
    }

}
