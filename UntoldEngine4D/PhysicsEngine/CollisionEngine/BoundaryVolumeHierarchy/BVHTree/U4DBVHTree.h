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
#include "U4DPoint3n.h"
#include "U4DVector3n.h"
#include "U4DAABB.h"


namespace U4DEngine {

    class U4DDynamicModel;

    /**
     @brief The U4DBVHTree class represents a node in a BVH tree and is used for Broad-Phase collision.
     */
    class U4DBVHTree{
        
    private:
        
        /**
         @brief AABB object which holds volume information about the node
         */
        U4DAABB* aabbVolume;
        
        /**
         @brief Tree node split index
         */
        int splitIndex;
        
        /**
         @brief Container holding 3D model entities
         */
        std::vector<U4DDynamicModel *> modelsContainer;
        
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DBVHTree();
        
        /**
         @brief Destructor for the class
         */
        ~U4DBVHTree();
        
        /**
         @brief Tree parent pointer
         */
        U4DBVHTree *parent;
        
        /**
         @brief Tree previous sibling pointer
         */
        U4DBVHTree *prevSibling;
        
        /**
         @brief Tree next pointer
         */
        U4DBVHTree *next;
        
        /**
         @brief Tree last descendant pointer
         */
        U4DBVHTree *lastDescendant;
        
        /**
         @brief Method which returns container with 3D model entities that are part of the tree node
         
         @return Returns container with 3D model entities that are part of the tree node
         */
        std::vector<U4DDynamicModel *> getModelsContainer();
        
        /**
         @brief Method which adds 3D models to the node container
         
         @param uModel 3D model entity
         */
        void addModelToContainer(U4DDynamicModel *uModel);
        
        /**
         @brief Method which add a 3D model at a particular index
         
         @param uIndex           index
         @param uModel 3D model entity
         */
        void addModelToContainerAtIndex(int uIndex, U4DDynamicModel *uModel);
        
        /**
         @brief Method which makes a copy of the model container
         
         @param uModelsContainer Model container
         */
        void copyModelsContainer(std::vector<U4DDynamicModel *> uModelsContainer);
        
        /**
         @brief Method which returns a pointer to the AABB holding volume information about the tree node
         
         @return Returns a pointer to the AABB holding volume information about the tree node
         */
        U4DAABB* getAABBVolume();
        
        /**
         @brief Method which sets a tree node split index
         
         @param uSplitIndex Split index
         */
        void setSplitIndex(int uSplitIndex);
        
        /**
         @brief Method which returns the tree node split index
         
         @return Returns the tree node split index
         */
        int getSplitIndex();
        
        //scenegraph
        
        /**
         @brief Method which adds a child node to a scenegraph
         
         @param uChild Child node to add to scenegraph
         */
        void addChild(U4DBVHTree *uChild);
        
        /**
         @brief Method which removes a child node from the scenegraph
         
         @param uChild Child node to remove from the scenegraph
         */
        void removeChild(U4DBVHTree *uChild);
        
        /**
         @brief Method which changes the node's last descendant in the scenegraph
         
         @param uNewLastDescendant Last descendant of the node
         */
        void changeLastDescendant(U4DBVHTree *uNewLastDescendant);
        
        /**
         @brief Method which returns the node's first child in the scenegraph
         
         @return Returns the node's first child
         */
        U4DBVHTree *getFirstChild();
        
        /**
         @brief Method which returns the node's last child in the scenegraph
         
         @return Returns the node's last child
         */
        U4DBVHTree *getLastChild();
        
        /**
         @brief Method which returns the node's next sibling in the scenegraph
         
         @return Returns the node's next sibling
         */
        U4DBVHTree *getNextSibling();
        
        /**
         @brief Method which returns the node's previous sibling in the scenegraph
         
         @return Returns the node's previous sibling
         */
        U4DBVHTree *getPrevSibling();
        
        /**
         @brief Method which returns the node's previous sibling in pre-order traversal order
         
         @return Returns the node's previous sibling in pre-order traversal order
         */
        U4DBVHTree *prevInPreOrderTraversal();
        
        /**
         @brief Method which returns the node's next pointer in pre-order traversal order
         
         @return Returns the node's next pointer in pre-order traversal order
         */
        U4DBVHTree *nextInPreOrderTraversal();
        
        /**
         @brief Method which returns true if the node represents a leaf node in the scenegraph
         
         @return Returns true if the node represents a leaf node in the scenegraph
         */
        bool isLeaf();
        
        /**
         @brief Method which returns true if the node represents a root node in the scenegraph
         
         @return Returns true if the node represents a root node in the scenegraph
         */
        bool isRoot();
    
    };
    
}


#endif /* U4DBVHTree_hpp */
