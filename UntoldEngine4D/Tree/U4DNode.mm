//
//  U4DNode.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNode_mm
#define U4DNode_mm

#include "U4DNode.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
    template <typename T>
    U4DNode<T>::U4DNode():parent(nullptr),next(nullptr){
        
        prevSibling=this;
        lastDescendant=this;
        
    }

    template <typename T>
    U4DNode<T>::U4DNode(std::string uNodeName):T(uNodeName),parent(nullptr),next(nullptr){
        
        prevSibling=this;
        lastDescendant=this;
        
    }
    
    template <typename T>
    U4DNode<T>::~U4DNode(){
        
        
    }
    

    //scenegraph methods
    template <typename T>
    void U4DNode<T>::addChild(U4DNode<T> *uChild){
        
        U4DNode* lastAddedChild=getFirstChild();
        
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

    template <typename T>
    void U4DNode<T>::removeChild(U4DNode<T> *uChild){
        
        U4DNode* sibling = uChild->getNextSibling();
        
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
    
    template <typename T>
    U4DNode<T> *U4DNode<T>::prevInPreOrderTraversal(){
        
        U4DNode* prev = 0;
        if (parent)
        {
            if (parent->next == this)
                prev = parent;
            else
                prev = prevSibling->lastDescendant;
        }
        return prev;
    }
    
    template <typename T>
    U4DNode<T> *U4DNode<T>::nextInPreOrderTraversal(){
        return next;
    }
    
    template <typename T>
    U4DNode<T> *U4DNode<T>::getFirstChild(){
        
        U4DNode* child=NULL;
        if(next && (next->parent==this)){
            child=next;
        }
        
        return child;
    }
    
    template <typename T>
    U4DNode<T> *U4DNode<T>::getLastChild(){
        
        U4DNode *child=getFirstChild();
        
        if(child){
            child=child->prevSibling;
        }
        
        return child;
    }
    
    template <typename T>
    U4DNode<T> *U4DNode<T>::getNextSibling(){
        
        U4DNode* sibling = lastDescendant->next;
        if (sibling && (sibling->parent != parent))
            sibling = 0;
        return sibling;
    }
    
    template <typename T>
    U4DNode<T> *U4DNode<T>::getPrevSibling(){
        U4DNode* sibling = 0;
        if (parent && (parent->next != this))
            sibling =prevSibling;
        return sibling;
    }
    
    template <typename T>
    void U4DNode<T>::changeLastDescendant(U4DNode<T> *uNewLastDescendant){
        
        U4DNode *oldLast=lastDescendant;
        U4DNode *ancestor=this;
        
        do{
            ancestor->lastDescendant=uNewLastDescendant;
            ancestor=ancestor->parent;
        }while (ancestor && (ancestor->lastDescendant==oldLast));
        
    }
    
    template <typename T>
    bool U4DNode<T>::isRoot(){
        
        bool value=false;
        
        if (parent==0) {
            
            value=true;
            
        }
        
        return value;
    }
    
    template <typename T>
    bool U4DNode<T>::isLeaf(){
        
        return (lastDescendant==this);
        
    }

    template <typename T>
    U4DNode<T>* U4DNode<T>::getParent(){
        
        return parent;
    }

    template <typename T>
    U4DNode<T>* U4DNode<T>::getRootParent(){
        
        U4DNode<T> *rootParent=parent;
        
        while (rootParent->isRoot()==false) {
            
            rootParent=rootParent->parent;
        }
        
        return rootParent;
    }

template <typename T>
U4DNode<T>* U4DNode<T>::searchChild(std::string uName){
    
    //get the first child
    U4DNode<T>* child=next;
    U4DNode<T>* childWithName=nullptr;
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    while (child!=NULL) {
        
        if (child->getName().compare(uName)!=0) {
            
            child=child->next;
            
        }else if (child->getName().compare(uName)==0){
            
            childWithName=child;
            
            break;
            
        }
        
    }
    
    if (childWithName==nullptr) {
        
        logger->log("Error: Child with name %s was not found.", uName.c_str());
        
    }
    
    return childWithName;
    
}

}

#endif

