//
//  U4DMeshOctreeNode.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/28/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DMeshOctreeNode.h"

namespace U4DEngine {
    
    U4DMeshOctreeNode::U4DMeshOctreeNode():parent(nullptr),next(nullptr){
        
        prevSibling=this;
        lastDescendant=this;
        
    }
    
    U4DMeshOctreeNode::~U4DMeshOctreeNode(){
        
    }
    
    //scenegraph methods
    void U4DMeshOctreeNode::addChild(U4DMeshOctreeNode *uChild){
        
        U4DMeshOctreeNode* lastAddedChild=getFirstChild();
        
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
        
    }
    
    void U4DMeshOctreeNode::removeChild(U4DMeshOctreeNode *uChild){
        
        U4DMeshOctreeNode* sibling = uChild->getNextSibling();
        
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
    
    U4DMeshOctreeNode *U4DMeshOctreeNode::prevInPreOrderTraversal(){
        
        U4DMeshOctreeNode* prev = 0;
        if (parent)
        {
            if (parent->next == this)
                prev = parent;
            else
                prev = prevSibling->lastDescendant;
        }
        return prev;
    }
    
    U4DMeshOctreeNode *U4DMeshOctreeNode::nextInPreOrderTraversal(){
        return next;
    }
    
    U4DMeshOctreeNode *U4DMeshOctreeNode::getFirstChild(){
        
        U4DMeshOctreeNode* child=NULL;
        if(next && (next->parent==this)){
            child=next;
        }
        
        return child;
    }
    
    U4DMeshOctreeNode *U4DMeshOctreeNode::getLastChild(){
        
        U4DMeshOctreeNode *child=getFirstChild();
        
        if(child){
            child=child->prevSibling;
        }
        
        return child;
    }
    
    U4DMeshOctreeNode *U4DMeshOctreeNode::getNextSibling(){
        
        U4DMeshOctreeNode* sibling = lastDescendant->next;
        if (sibling && (sibling->parent != parent))
            sibling = 0;
        return sibling;
    }
    
    
    U4DMeshOctreeNode *U4DMeshOctreeNode::getPrevSibling(){
        U4DMeshOctreeNode* sibling = 0;
        if (parent && (parent->next != this))
            sibling =prevSibling;
        return sibling;
    }
    
    void U4DMeshOctreeNode::changeLastDescendant(U4DMeshOctreeNode *uNewLastDescendant){
        
        U4DMeshOctreeNode *oldLast=lastDescendant;
        U4DMeshOctreeNode *ancestor=this;
        
        do{
            ancestor->lastDescendant=uNewLastDescendant;
            ancestor=ancestor->parent;
        }while (ancestor && (ancestor->lastDescendant==oldLast));
        
    }
    
    bool U4DMeshOctreeNode::isRoot(){
        
        bool value=false;
        
        if (parent==0) {
            
            value=true;
            
        }
        
        return value;
    }
    
    bool U4DMeshOctreeNode::isLeaf(){
        
        return (lastDescendant==this);
        
    }
    
    
}
