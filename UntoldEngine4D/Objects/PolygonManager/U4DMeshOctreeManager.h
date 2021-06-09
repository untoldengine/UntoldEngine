//
//  U4DMeshOctreeManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/28/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMeshOctreeManager_hpp
#define U4DMeshOctreeManager_hpp

#include <stdio.h>
#include <vector>
#include "U4DMeshOctreeNode.h"
#include "U4DModel.h"
#include "U4DPoint3n.h"
#include "U4DVector3n.h"
#include "U4DMeshOctreeNode.h"



namespace U4DEngine {
    
    /**
     @brief The U4DMeshOctreeManager class builds an octree bounding a 3d model
     */
    class U4DMeshOctreeManager {
        
    private:
        
        /**
         @brief Pointer to the root tree container
         */
        std::vector<std::shared_ptr<U4DMeshOctreeNode>> treeContainer;
        
        /**
         @brief Pointer to the model whose octree will be based on
         */
        U4DModel *model;
        
        /**
         @brief vector container of the mesh faces in absolute space
         */
        std::vector<U4DTriangle> meshFacesAbsoluteSpaceContainer;
        
    public:
        
        /**
         @brief constructor for the U4DMeshOctreeManager. The constructor transforms the 3d mesh faces from local space to absolute space
         @param uModel pointer to the model whose octree will be based on
         */
        U4DMeshOctreeManager(U4DModel *uModel);
        
        /**
         @brief Destructor for the U4DMeshOctreeManager
         */
        ~U4DMeshOctreeManager();
        
        /**
         @brief Builds the octree
         @details Builds an octree for the 3D model using AABB boxes
         @param uSubDivisions The subdivisions used for the octree. 1 subdivision=9 nodes, 2 subdivisions=73 node, 3 subdivisions=585 nodes
         */
        void buildOctree(int uSubDivisions);
        
        /**
         @brief Builds the octree nodes
         @param uNode Octree node
         @param uCenter center of the AABB box
         @param uSubDivisions current subdivision of the the octree
         */
        void buildOctreeNode(U4DMeshOctreeNode *uNode, U4DPoint3n &uCenter, float uHalfwidth, int uSubDivisions);
        
        /**
         @brief Assigns triangles(faces) of the 3D model mesh to node leaves
         */
        void assignFacesToNodeLeaf();
        
        /**
         @brief Returns a pointer to the octree 
         */
        U4DMeshOctreeNode *getRootNode();
        
        /**
         @brief Transforms the mesh faces of the 3D model from local space to absolute space
         */
        void computeMeshFacesAbsoluteSpace();
        
        /**
         @brief returns the mesh faces in absolute space
         */
        std::vector<U4DTriangle> getMeshFacesAbsoluteSpaceContainer();
        
    };
    
}


#endif /* U4DMeshManager_hpp */
