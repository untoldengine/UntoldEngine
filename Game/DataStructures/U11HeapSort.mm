//
//  U11HeapSort.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11HeapSort.h"

U11HeapSort::U11HeapSort(){
    
}

U11HeapSort::~U11HeapSort(){
    
}

void U11HeapSort::heapify(std::vector<U11Node> &uContainer){
    
    int index=0;
    
    int numValues=(int)uContainer.size();
    
    //convert the array of values into a heap
    for (index=numValues/2-1; index>=0; index--) {
        
        reHeapDown(uContainer,index,numValues-1);
    }
    
    //sort the array
    for (index=numValues-1; index>=1; index--) {
        
        swap(uContainer,0,index);
        reHeapDown(uContainer,0,index-1);
        
    }

    
}

void U11HeapSort::reHeapDown(std::vector<U11Node> &uContainer,int root, int bottom){
    
    int maxChild;
    int rightChild;
    int leftChild;
    
    leftChild=root*2+1;
    rightChild=root*2+2;
    
    if (leftChild<=bottom) {
        
        if (leftChild==bottom) {
            
            maxChild=leftChild;
            
        }else{
            
            if (uContainer.at(leftChild).data<=uContainer.at(rightChild).data) {
                
                maxChild=rightChild;
                
            }else{
                maxChild=leftChild;
            }
        }
        
        if (uContainer.at(root).data<uContainer.at(maxChild).data) {
            
            swap(uContainer,root,maxChild);
            reHeapDown(uContainer,maxChild,bottom);
        }
    }
    
}



void U11HeapSort::swap(std::vector<U11Node> &uContainer,int uIndex1, int uIndex2){
    
    U11Node node1=uContainer.at(uIndex1);
    U11Node node2=uContainer.at(uIndex2);
    
    uContainer.at(uIndex1)=node2;
    uContainer.at(uIndex2)=node1;
    
}
