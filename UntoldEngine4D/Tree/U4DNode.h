//
//  U4DNode.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNode_hpp
#define U4DNode_hpp

#include <stdio.h>
#include <vector>

namespace U4DEngine {

    /**
     @ingroup physicsengine
     @brief The U4DNode class represents a node in a Generic tree.
     */
    template <typename T>
    class U4DNode: public T{
        
    private:
        
        
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DNode();
        
        U4DNode(std::string uNodeName);
        
        /**
         @brief Destructor for the class
         */
        ~U4DNode();
        
        /**
         @brief Tree parent pointer
         */
        U4DNode<T> *parent;
        
        /**
         @brief Tree previous sibling pointer
         */
        U4DNode<T> *prevSibling;
        
        /**
         @brief Tree next pointer
         */
        U4DNode<T> *next;
        
        /**
         @brief Tree last descendant pointer
         */
        U4DNode<T> *lastDescendant;
        
        //scenegraph
        
        /**
         @brief Method which adds a child node to a scenegraph
         
         @param uChild Child node to add to scenegraph
         */
        void addChild(U4DNode<T> *uChild);
        
        /**
         @brief Method which removes a child node from the scenegraph
         
         @param uChild Child node to remove from the scenegraph
         */
        void removeChild(U4DNode<T> *uChild);
        
        /**
         @brief Method which changes the node's last descendant in the scenegraph
         
         @param uNewLastDescendant Last descendant of the node
         */
        void changeLastDescendant(U4DNode<T> *uNewLastDescendant);
        
        /**
         @brief Method which returns the node's first child in the scenegraph
         
         @return Returns the node's first child
         */
        U4DNode<T> *getFirstChild();
        
        /**
         @brief Method which returns the node's last child in the scenegraph
         
         @return Returns the node's last child
         */
        U4DNode<T> *getLastChild();
        
        /**
         @brief Method which returns the node's next sibling in the scenegraph
         
         @return Returns the node's next sibling
         */
        U4DNode<T> *getNextSibling();
        
        /**
         @brief Method which returns the node's previous sibling in the scenegraph
         
         @return Returns the node's previous sibling
         */
        U4DNode<T> *getPrevSibling();
        
        /**
         @brief Method which returns the node's previous sibling in pre-order traversal order
         
         @return Returns the node's previous sibling in pre-order traversal order
         */
        U4DNode<T> *prevInPreOrderTraversal();
        
        /**
         @brief Method which returns the node's next pointer in pre-order traversal order
         
         @return Returns the node's next pointer in pre-order traversal order
         */
        U4DNode<T> *nextInPreOrderTraversal();
        
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
        U4DNode<T>* getParent();
        
        
        /**
         @brief Gets the root parent (top parent in the scenegraph) of the entity

         @return pointer to the root parent
         */
        U4DNode<T>* getRootParent();
        
        U4DNode<T>* searchChild(std::string uName);
    };
    
}

#include "U4DNode.mm"

#endif /* U4DNode_hpp */
