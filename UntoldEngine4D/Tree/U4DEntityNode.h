//
//  U4DEntityNode.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DEntityNode_hpp
#define U4DEntityNode_hpp

#include <stdio.h>
#include <vector>

namespace U4DEngine {

    /**
     @ingroup gameobjects
     @brief The U4DEntityNode class represents a node in a Generic tree.
     */
    template <typename T>

    class U4DEntityNode{
        
    private:
        
    protected:
        
       
        
    public:
        
        /**
         @brief Tree parent pointer
         */
        T *parent;
        
        /**
         @brief Tree previous sibling pointer
         */
        T *prevSibling;
        
        /**
         @brief Tree next pointer
         */
        T *next;
        
        /**
         @brief Tree last descendant pointer
         */
        T *lastDescendant;
        
        
        /**
         @brief Constructor for the class
         */
        U4DEntityNode();
        
        U4DEntityNode(std::string uNodeName);
        
        /**
         @brief Destructor for the class
         */
        ~U4DEntityNode();
        
        
        
        //scenegraph
        
        /**
         @brief Method which adds a child node to a scenegraph
         
         @param uChild Child node to add to scenegraph
         */
        void addChild(T *uChild);
        
        void addChild(T *uChild, T *uNext);
        
        /**
         @brief Method which removes a child node from the scenegraph
         
         @param uChild Child node to remove from the scenegraph
         */
        void removeChild(T *uChild);
        
        /**
         @brief Method which changes the node's last descendant in the scenegraph
         
         @param uNewLastDescendant Last descendant of the node
         */
        void changeLastDescendant(T *uNewLastDescendant);
        
        /**
         @brief Method which returns the node's first child in the scenegraph
         
         @return Returns the node's first child
         */
        T *getFirstChild();
        
        /**
         @brief Method which returns the node's last child in the scenegraph
         
         @return Returns the node's last child
         */
        T *getLastChild();
        
        /**
         @brief Method which returns the node's next sibling in the scenegraph
         
         @return Returns the node's next sibling
         */
        T *getNextSibling();
        
        /**
         @brief Method which returns the node's previous sibling in the scenegraph
         
         @return Returns the node's previous sibling
         */
        T *getPrevSibling();
        
        /**
         @brief Method which returns the node's previous sibling in pre-order traversal order
         
         @return Returns the node's previous sibling in pre-order traversal order
         */
        T *prevInPreOrderTraversal();
        
        /**
         @brief Method which returns the node's next pointer in pre-order traversal order
         
         @return Returns the node's next pointer in pre-order traversal order
         */
        T *nextInPreOrderTraversal();
        
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
        
        /**
         @brief Gets the parent to the entity

         @return pointer to the entity parent
         */
        T* getParent();
        
        /**
         @brief Method which adds a child entity to a scenegraph at a particular location
         
         @param uChild Child entity to add to scenegraph
         @param uZDepth location to insert child
         */
        void addChild(T *uChild, int uZDepth);
        
        
        /**
         @brief Gets the root parent (top parent in the scenegraph) of the entity

         @return pointer to the root parent
         */
        T* getRootParent();
        
        T* searchChild(std::string uName);
    };
    
}

#include "U4DEntityNode.mm"

#endif /* U4DEntityNode_hpp */
