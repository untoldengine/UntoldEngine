//
//  U4DMeshOctreeNode.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/28/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMeshOctreeNode_hpp
#define U4DMeshOctreeNode_hpp

#include <stdio.h>
#include <vector>
#include "U4DAABB.h"

namespace U4DEngine {
    
    /**
     @brief The U4DMeshOctreeNode class represents a node of the octree bounding a 3d model
     */
    class U4DMeshOctreeNode {
        
    private:
        
    public:
        
        /**
         @brief Vector container storing all the triangles(faces) intersecting the AABB node
         */
        std::vector<int> triangleIndexContainer;
        
        /**
         @brief AABB object which holds volume information about the node
         */
        U4DAABB aabbVolume;
        
        /**
         @brief Octree Node constructor
         */
        U4DMeshOctreeNode();
        
        /**
         @brief Octree Node destructor
         */
        ~U4DMeshOctreeNode();
        
        /**
         @brief Tree parent pointer
         */
        U4DMeshOctreeNode *parent;
        
        /**
         @brief Tree previous sibling pointer
         */
        U4DMeshOctreeNode *prevSibling;
        
        /**
         @brief Tree next pointer
         */
        U4DMeshOctreeNode *next;
        
        /**
         @brief Tree last descendant pointer
         */
        U4DMeshOctreeNode *lastDescendant;
        
        /**
         @brief Method which adds a child node to a scenegraph
         
         @param uChild Child node to add to scenegraph
         */
        void addChild(U4DMeshOctreeNode *uChild);
        
        /**
         @brief Method which removes a child node from the scenegraph
         
         @param uChild Child node to remove from the scenegraph
         */
        void removeChild(U4DMeshOctreeNode *uChild);
        
        /**
         @brief Method which changes the node's last descendant in the scenegraph
         
         @param uNewLastDescendant Last descendant of the node
         */
        void changeLastDescendant(U4DMeshOctreeNode *uNewLastDescendant);
        
        /**
         @brief Method which returns the node's first child in the scenegraph
         
         @return Returns the node's first child
         */
        U4DMeshOctreeNode *getFirstChild();
        
        /**
         @brief Method which returns the node's last child in the scenegraph
         
         @return Returns the node's last child
         */
        U4DMeshOctreeNode *getLastChild();
        
        /**
         @brief Method which returns the node's next sibling in the scenegraph
         
         @return Returns the node's next sibling
         */
        U4DMeshOctreeNode *getNextSibling();
        
        /**
         @brief Method which returns the node's previous sibling in the scenegraph
         
         @return Returns the node's previous sibling
         */
        U4DMeshOctreeNode *getPrevSibling();
        
        /**
         @brief Method which returns the node's previous sibling in pre-order traversal order
         
         @return Returns the node's previous sibling in pre-order traversal order
         */
        U4DMeshOctreeNode *prevInPreOrderTraversal();
        
        /**
         @brief Method which returns the node's next pointer in pre-order traversal order
         
         @return Returns the node's next pointer in pre-order traversal order
         */
        U4DMeshOctreeNode *nextInPreOrderTraversal();
        
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


#endif /* U4DPolygonTree_hpp */
