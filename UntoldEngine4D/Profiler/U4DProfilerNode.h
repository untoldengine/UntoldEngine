//
//  U4DProfilerNode.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DProfilerNode_hpp
#define U4DProfilerNode_hpp

#include <stdio.h>
#include <chrono>
#include <string>

namespace U4DEngine {

    class U4DProfilerNode {
        
    private:
        
        std::string name;
        
        //start time
        std::chrono::steady_clock::time_point startTime;
        //end time
        
        //total time
        float totalTime;
        
        float timeAccumulator;
        
    public:
        
        U4DProfilerNode(std::string uNodeName);
        
        ~U4DProfilerNode();
        
        void startProfiling();
        
        void stopProfiling();
        
        float getTotalTime();
        
        std::string getName();
        
        /**
         @brief Entity parent pointer
         */
        U4DProfilerNode *parent;
        
        /**
         @brief Entity previous sibling pointer
         */
        U4DProfilerNode *prevSibling;

        /**
         @brief Entity Next pointer
         */
        U4DProfilerNode *next;
        
        /**
         @brief Entity last descendant pointer
         */
        U4DProfilerNode *lastDescendant;
        
        //scenegraph
        /**
         @brief Method which adds a node entity to the tree
         
         @param uChild Child entity to add to tree
         */
        void addChild(U4DProfilerNode *uChild);
        
        /**
         @brief Method which removes a node entity from the tree
         
         @param uChild Child entity to remove from the treeh
         */
        void removeChild(U4DProfilerNode *uChild);
        
        /**
         @brief Method which changes the entity's last descendant in the tree
         
         @param uNewLastDescendant Last descendant of the entity
         */
        void changeLastDescendant(U4DProfilerNode *uNewLastDescendant);
        
        /**
         @brief Method which returns the entity's first child in the tree
         
         @return Returns the entity's first child
         */
        U4DProfilerNode *getFirstChild();
        
        /**
         @brief Method which returns the entity's last child in the tree
         
         @return Returns the entity's last child
         */
        U4DProfilerNode *getLastChild();
        
        /**
         @brief Method which returns the entity's next sibling in the tree
         
         @return Returns the entity's next sibling
         */
        U4DProfilerNode *getNextSibling();
        
        /**
         @brief Method which returns the entity's previous sibling in the tree
         
         @return Returns the entity's previous sibling
         */
        U4DProfilerNode *getPrevSibling();
        
        /**
         @brief Method which returns the entity's previous sibling in pre-order traversal order
         
         @return Returns the entity's previous sibling in pre-order traversal order
         */
        U4DProfilerNode *prevInPreOrderTraversal();
        
        /**
         @brief Method which returns the entity's next pointer in pre-order traversal order
         
         @return Returns the entity's next pointer in pre-order traversal order
         */
        U4DProfilerNode *nextInPreOrderTraversal();
        
        /**
         @brief Method which returns true if the entity represents a leaf node in the tree
         
         @return Returns true if the entity represents a leaf node in the tree
         */
        bool isLeaf();
        
        /**
         @brief Method which returns true if the entity represents a root node in the tree
         
         @return Returns true if the entity represents a root node in the tree
         */
        bool isRoot();
        
        U4DProfilerNode *searchChild(std::string uName);
        
        U4DProfilerNode* getParent();
        
        /**
         @brief Gets the root parent (top parent in the scenegraph) of the node

         @return pointer to the root parent
         */
        U4DProfilerNode* getRootParent();
        
    };

}

#endif /* U4DProfilerNode_hpp */
