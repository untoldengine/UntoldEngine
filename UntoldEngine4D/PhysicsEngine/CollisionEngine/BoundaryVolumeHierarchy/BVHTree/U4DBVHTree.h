//
//  U4DBVHTree.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/13/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DBVHTree_hpp
#define U4DBVHTree_hpp

#include <stdio.h>
#include <vector>

class U4DDynamicModel;

namespace U4DEngine {
 
    class U4DBVHTree{
        
    private:
        
        U4DBVHTree *parent;
        
        U4DBVHTree *prevSibling;
        
        U4DBVHTree *next;
        
        U4DBVHTree *lastDescendant;
        
        std::vector<U4DDynamicModel *> models;
        
        
    public:
        
        U4DBVHTree();
        
        ~U4DBVHTree();
        
        //scenegraph
        
        void addChild(U4DBVHTree *uChild);
        
        void removeChild(U4DBVHTree *uChild);
        
        void changeLastDescendant(U4DBVHTree *uNewLastDescendant);
        
        U4DBVHTree *getFirstChild();
        
        U4DBVHTree *getLastChild();
        
        U4DBVHTree *getNextSibling();
        
        U4DBVHTree *getPrevSibling();
        
        U4DBVHTree *prevInPreOrderTraversal();
        
        U4DBVHTree *nextInPreOrderTraversal();
        
        bool isLeaf();
        
        bool isRoot();
        
    };
    
}


#endif /* U4DBVHTree_hpp */
