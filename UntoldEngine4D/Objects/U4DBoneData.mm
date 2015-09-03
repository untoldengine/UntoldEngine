//
//  U4DBoneData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DBoneData.h"

namespace U4DEngine {
    
    U4DBoneData::U4DBoneData(){

        parent=NULL;
        next=NULL;
        prevSibling=this;
        lastDescendant=this;
        index=0;    //set index number as zero
        
    }

    U4DBoneData::~U4DBoneData(){

    }

    void U4DBoneData::addBoneToTree(U4DBoneData *uChild){
        
        U4DBoneData* lastAddedChild=getFirstChild();
        
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

    void U4DBoneData::removeBoneFromTree(U4DBoneData *uChild){
        
        U4DBoneData* sibling = uChild->getNextSibling();
        
        if (sibling)
            sibling->prevSibling = uChild->prevSibling;
        else
            getFirstChild()->prevSibling = uChild->prevSibling;
        
        if (lastDescendant == uChild->lastDescendant)
            changeLastDescendant(uChild->prevInPreOrderTraversal());
        
        if (next == uChild)	// deleting first child?
            next = uChild->lastDescendant->next;
        else
            uChild->prevSibling->lastDescendant->next = uChild->lastDescendant->next;
    }

    U4DBoneData *U4DBoneData::prevInPreOrderTraversal(){
        
        U4DBoneData* prev = 0;
        if (parent)
        {
            if (parent->next == this)
                prev = parent;
            else
                prev = prevSibling->lastDescendant;
        }
        return prev;
    }

    U4DBoneData *U4DBoneData::nextInPreOrderTraversal(){
        return next;
    }

    U4DBoneData *U4DBoneData::getFirstChild(){
        
        U4DBoneData* child=NULL;
        if(next && (next->parent==this)){
            child=next;
        }
        
        return child;
    }

    U4DBoneData *U4DBoneData::getLastChild(){
        
        U4DBoneData *child=getFirstChild();
        
        if(child){
            child=child->prevSibling;
        }
        
        return child;
    }

    U4DBoneData *U4DBoneData::getNextSibling(){
        
        U4DBoneData* sibling = lastDescendant->next;
        if (sibling && (sibling->parent != parent))
            sibling = 0;
        return sibling;
    }


    U4DBoneData *U4DBoneData::getPrevSibling(){
        U4DBoneData* sibling = 0;
        if (parent && (parent->next != this))
            sibling =prevSibling;
        return sibling;
    }

    void U4DBoneData::changeLastDescendant(U4DBoneData *uNewLastDescendant){
        
        U4DBoneData *oldLast=lastDescendant;
        U4DBoneData *ancestor=this;
        
        do{
            ancestor->lastDescendant=uNewLastDescendant;
            ancestor=ancestor->parent;
        }while (ancestor && (ancestor->lastDescendant==oldLast));
        
    }

    bool U4DBoneData::isRoot(){
        
        bool value=false;
        
        if (parent==0) {
            
            value=true;
            
        }
        
        return value;
    }

    bool U4DBoneData::isLeaf(){
        
        return lastDescendant=this;
        
    }

    void U4DBoneData::iterateChildren(){
        
        /*
        U4DBoneData* iterate;
        
        for (iterate=getFirstChild(); iterate!=NULL;iterate=iterate->getNextSibling()) {
            
            cout<<iterate->name;
            iterate->iterateChildren();
        
            
        }
        */
    }


    U4DBoneData *U4DBoneData::searchChildrenBone(std::string uBoneName){
        
        U4DBoneData *boneChild;
        
        boneChild=this;
        
        while (boneChild->name.compare(uBoneName)!=0) {
            
            boneChild=boneChild->next;
            
        }
        
        return boneChild;
    }

}
