//
//  U11HeapSort.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11HeapSort_hpp
#define U11HeapSort_hpp

#include <stdio.h>
#include "U11Node.h"
#include <vector>

class U11HeapSort {
    
private:
    
public:
    
    U11HeapSort();
    
    ~U11HeapSort();
    
    void heapify(std::vector<U11Node> &uContainer);
    
    void reHeapDown(std::vector<U11Node> &uContainer, int root, int bottom);
    
    void swap(std::vector<U11Node> &uContainer, int uindex1, int uindex2);
};

#endif /* U11HeapSort_hpp */
