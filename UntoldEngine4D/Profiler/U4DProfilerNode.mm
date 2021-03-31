//
//  U4DProfilerNode.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DProfilerNode.h"
#include "U4DLogger.h"

namespace U4DEngine {

U4DProfilerNode::U4DProfilerNode(std::string uNodeName):parent(nullptr),next(nullptr),timeAccumulator(0.0),name(uNodeName){
    
        prevSibling=this;
        lastDescendant=this;
        
    }
        
    U4DProfilerNode::~U4DProfilerNode(){
        
    }

    void U4DProfilerNode::startProfiling(){
        
        //start the time
        startTime=std::chrono::steady_clock::now();
    }
        
    void U4DProfilerNode::stopProfiling(){
        
        std::chrono::steady_clock::time_point endTime = std::chrono::steady_clock::now();
        
        totalTime=std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime).count();
        
        //smooth out the value by using a Recency Weighted Average.
        //The RWA keeps an average of the last few values, with more recent values being more
        //significant. The bias parameter controls how much significance is given to previous values.
        //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
        //A bias of 1 ignores the new value altogether.
        float biasMotionAccumulator=0.9;
        
        timeAccumulator=timeAccumulator*biasMotionAccumulator+totalTime*(1.0-biasMotionAccumulator);
        
        totalTime=timeAccumulator;
    
    }

    float U4DProfilerNode::getTotalTime(){
        
        return totalTime;
        
    }

    //scenegraph methods
    void U4DProfilerNode::addChild(U4DProfilerNode *uChild){
        
        if (uChild!=NULL) {
            
            U4DProfilerNode* lastAddedChild=getFirstChild();
            
            if(lastAddedChild==0){ //add as first child
                
                uChild->parent=this;
                
                uChild->lastDescendant->next=lastDescendant->next;
                
                lastDescendant->next=uChild;
                
                uChild->prevSibling=getLastChild();
                
                if (isLeaf()) {
                    
                    next=uChild;
                    
                }
                
                getFirstChild()->prevSibling=uChild;
                
                changeLastDescendant(uChild->lastDescendant);
                
                
            }else{
                
                uChild->parent=lastAddedChild->parent;
                
                uChild->prevSibling=lastAddedChild->prevSibling;
                
                uChild->lastDescendant->next=lastAddedChild;
                
                if (lastAddedChild->parent->next==lastAddedChild) {
                    lastAddedChild->parent->next=uChild;
                }else{
                    lastAddedChild->prevSibling->lastDescendant->next=uChild;
                }
                
                lastAddedChild->prevSibling=uChild;
                
            }
            
        }else{
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("Error: An entity seems to be un-initialized. This entity was not loaded into the scenegraph");
        }
        
    }
    
    void U4DProfilerNode::removeChild(U4DProfilerNode *uChild){
        
        U4DProfilerNode* sibling = uChild->getNextSibling();
        
        if (sibling)
            sibling->prevSibling = uChild->prevSibling;
        else
            getFirstChild()->prevSibling = uChild->prevSibling;
        
        if (lastDescendant == uChild->lastDescendant)
            changeLastDescendant(uChild->prevInPreOrderTraversal());
        
        if (next == uChild)    // deleting first child?
            next = uChild->lastDescendant->next;
        else
            uChild->prevSibling->lastDescendant->next = uChild->lastDescendant->next;
        
    }

    U4DProfilerNode *U4DProfilerNode::prevInPreOrderTraversal(){
        
        U4DProfilerNode* prev = 0;
        if (parent)
        {
            if (parent->next == this)
                prev = parent;
            else
                prev = prevSibling->lastDescendant;
        }
        return prev;
    }

    U4DProfilerNode *U4DProfilerNode::nextInPreOrderTraversal(){
        return next;
    }

    U4DProfilerNode *U4DProfilerNode::getFirstChild(){
        
        U4DProfilerNode* child=NULL;
        if(next && (next->parent==this)){
            child=next;
        }
        
        return child;
    }

    U4DProfilerNode *U4DProfilerNode::getLastChild(){
        
        U4DProfilerNode *child=getFirstChild();
        
        if(child){
            child=child->prevSibling;
        }
        
        return child;
    }

    U4DProfilerNode *U4DProfilerNode::getNextSibling(){
        
        U4DProfilerNode* sibling = lastDescendant->next;
        if (sibling && (sibling->parent != parent))
            sibling = 0;
        return sibling;
    }


    U4DProfilerNode *U4DProfilerNode::getPrevSibling(){
        U4DProfilerNode* sibling = 0;
        if (parent && (parent->next != this))
            sibling =prevSibling;
        return sibling;
    }

    void U4DProfilerNode::changeLastDescendant(U4DProfilerNode *uNewLastDescendant){
        
        U4DProfilerNode *oldLast=lastDescendant;
        U4DProfilerNode *ancestor=this;
        
        do{
            ancestor->lastDescendant=uNewLastDescendant;
            ancestor=ancestor->parent;
        }while (ancestor && (ancestor->lastDescendant==oldLast));
        
    }

    bool U4DProfilerNode::isRoot(){
        
        bool value=false;
        
        if (parent==0) {
            
            value=true;
            
        }
        
        return value;
    }

    bool U4DProfilerNode::isLeaf(){
        
        return (lastDescendant==this);
        
    }
    
    U4DProfilerNode* U4DProfilerNode::getParent(){
        
        return parent;
    }
    
    U4DProfilerNode* U4DProfilerNode::getRootParent(){
        
        U4DProfilerNode *rootParent=parent;
        
        while (rootParent->isRoot()==false) {
            
            rootParent=rootParent->parent;
        }
        
        return rootParent;
    }

    U4DProfilerNode *U4DProfilerNode::searchChild(std::string uName){
        
        //get the first child
        U4DProfilerNode* child=next;
        U4DProfilerNode* childWithName=nullptr;
        
        while (child!=NULL) {
            
            if (child->getName().compare(uName)!=0) {
                
                child=child->next;
                
            }else if (child->getName().compare(uName)==0){
                
                childWithName=child;
                
                break;
                
            }
            
        }
        
        return childWithName;
        
    }

    std::string U4DProfilerNode::getName(){
        return name;
    }

}
