//
//  U4DEntityNode.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DEntityNode_mm
#define U4DEntityNode_mm

#include "U4DEntityNode.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
    template <typename T>
    U4DEntityNode<T>::U4DEntityNode():parent(nullptr),next(nullptr),pModel(nullptr),pDynamicAction(nullptr){
        
        prevSibling=static_cast<T*>(this);
        lastDescendant=static_cast<T*>(this);
        
    }

    template <typename T>
    U4DEntityNode<T>::U4DEntityNode(std::string uNodeName):T(uNodeName),parent(nullptr),next(nullptr){
        
        prevSibling=static_cast<T*>(this);
        lastDescendant=static_cast<T*>(this);
        
    }
    
    template <typename T>
    U4DEntityNode<T>::~U4DEntityNode(){
        
        
    }
    

    //scenegraph methods
    template <typename T>
    void U4DEntityNode<T>::addChild(T *uChild){
        
        T* lastAddedChild=getFirstChild();
        
        if(lastAddedChild==0){ //add as first child
            
            uChild->parent=static_cast<T*>(this);
            
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
    void U4DEntityNode<T>::addChild(T *uChild, T *uNext){
            
            if (uChild!=NULL) {
            
                if (uNext == 0)
                {
                    // append as last uChild
                    uChild->parent = static_cast<T*>(this);
                    uChild->lastDescendant->next = lastDescendant->next;
                    lastDescendant->next = uChild;
                    
                    uChild->prevSibling = getLastChild();
                    if (isLeaf())
                        next = uChild;
                    getFirstChild()->prevSibling = uChild;
                    
                    changeLastDescendant(uChild->lastDescendant);
                }
                else
                {
                    uChild->parent = uNext->parent;
                    
                    uChild->prevSibling = uNext->prevSibling;
                    
                    uChild->lastDescendant->next = uNext;
                    if (uChild->parent->next == uNext)    // inserting before first uChild?
                        uChild->parent->next = uChild;
                    else
                        uNext->prevSibling->lastDescendant->next = uChild;
                    
                    uNext->prevSibling = uChild;
                }
                
            }else{
                U4DLogger *logger=U4DLogger::sharedInstance();
                
                logger->log("Error: An entity seems to be un-initialized. This entity was not loaded into the scenegraph");
            }
            
        }

    template <typename T>
    void U4DEntityNode<T>::addChild(T *uChild, int uZDepth){
        
            if (uChild!=NULL) {

                uChild->zDepth=uZDepth;

                //get child
                T *child=static_cast<T*>(this)->next;

                //load children into a container
                std::vector<T*> entityContainer;

                while (child!=nullptr) {

                    entityContainer.push_back(child);

                    child=child->next;
                }

                //get the lowest zdepth child
                child=nullptr;

                for(auto n:entityContainer){

                    if (n->getZDepth()>=uZDepth) {

                        child=n;

                    }else{
                        break;
                    }

                }

                if (child==nullptr) {

                    addChild(uChild);

                }else{

                    addChild(uChild,child->next);

                }

            }else{
                U4DLogger *logger=U4DLogger::sharedInstance();

                logger->log("Error: An entity seems to be un-initialized. This entity was not loaded into the scenegraph");
            }
        
    }

    template <typename T>
    void U4DEntityNode<T>::removeChild(T *uChild){
        
        T* sibling = uChild->getNextSibling();
        
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
    void U4DEntityNode<T>::removeAllChildren(){
        
        T *tempParent=static_cast<T*>(this);
        T *child=lastDescendant;
        
        while (child!=nullptr) {
            
            if (child==tempParent) break;
            
            T *tempChild=child;
            
            child=child->prevInPreOrderTraversal();
            
            tempParent->removeChild(tempChild);
        }
        
        prevSibling=static_cast<T*>(this);
        lastDescendant=static_cast<T*>(this);
        next=nullptr;
    }

    template <typename T>
    void U4DEntityNode<T>::removeAndDeleteAllChildren(){
        
        T *tempParent=static_cast<T*>(this);
        T *child=lastDescendant;
        
        while (child!=nullptr) {
            
            if (child==tempParent) break;
            
            T *tempChild=child;
            
            child=child->prevInPreOrderTraversal();
            
            tempParent->removeChild(tempChild);
            
            delete tempChild;
            
            tempChild=nullptr;
        }
        
        prevSibling=static_cast<T*>(this);
        lastDescendant=static_cast<T*>(this);
        next=nullptr;
        
    }
    
    template <typename T>
    T* U4DEntityNode<T>::prevInPreOrderTraversal(){
        
        T* prev = 0;
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
    T* U4DEntityNode<T>::nextInPreOrderTraversal(){
        return next;
    }
    
    template <typename T>
    T* U4DEntityNode<T>::getFirstChild(){
        
        T* child=NULL;
        if(next && (next->parent==this)){
            child=next;
        }
        
        return child;
    }
    
    template <typename T>
    T* U4DEntityNode<T>::getLastChild(){
        
        T *child=getFirstChild();
        
        if(child){
            child=child->prevSibling;
        }
        
        return child;
    }
    
    template <typename T>
    T* U4DEntityNode<T>::getNextSibling(){
        
        T* sibling = lastDescendant->next;
        if (sibling && (sibling->parent != parent))
            sibling = 0;
        return sibling;
    }
    
    template <typename T>
    T* U4DEntityNode<T>::getPrevSibling(){
        T* sibling = 0;
        if (parent && (parent->next != this))
            sibling =prevSibling;
        return sibling;
    }
    
    template <typename T>
    void U4DEntityNode<T>::changeLastDescendant(T *uNewLastDescendant){
        
        T *oldLast=lastDescendant;
        T *ancestor=static_cast<T*>(this);
        
        do{
            ancestor->lastDescendant=uNewLastDescendant;
            ancestor=ancestor->parent;
        }while (ancestor && (ancestor->lastDescendant==oldLast));
        
    }
    
    template <typename T>
    bool U4DEntityNode<T>::isRoot(){
        
        bool value=false;
        
        if (parent==0) {
            
            value=true;
            
        }
        
        return value;
    }
    
    template <typename T>
    bool U4DEntityNode<T>::isLeaf(){
        
        return (lastDescendant==this);
        
    }

    template <typename T>
    T* U4DEntityNode<T>::getParent(){
        
        return parent;
    }

    template <typename T>
    T* U4DEntityNode<T>::getRootParent(){
        
        T *rootParent=parent;
        
        while (rootParent->isRoot()==false) {
            
            rootParent=rootParent->parent;
        }
        
        return rootParent;
    }

template <typename T>
T* U4DEntityNode<T>::searchChild(std::string uName){
    
    T* child=static_cast<T*>(this);
    T* childWithName=nullptr;
    
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
    
template <typename T>
T* U4DEntityNode<T>::searchChild(int uChildId){
    
    T* child=static_cast<T*>(this);
    T* childWithId=nullptr;
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    while (child!=NULL) {
        
        if (child->getEntityId()!=uChildId) {
            
            child=child->next;
            
        }else if (child->getEntityId()==uChildId){
            
            childWithId=child;
            
            break;
            
        }
        
    }
    
    if (childWithId==nullptr) {
        
        logger->log("Error: Child with Id %d was not found.", uChildId);
        
    }
    
    return childWithId;
    
}

}

#endif
