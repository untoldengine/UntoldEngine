//
//  U4DVertexData.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DVertexData__
#define __UntoldEngine__U4DVertexData__

#include <iostream>
#include <vector>
#include "U4DVector2n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DIndex.h"
#include "U4DSegment.h"
#include "U4DTriangle.h"
#include "U4DBoneIndices.h"


namespace U4DEngine {
    
    /**
     @brief The U4DVertexData represents attribute data for a 3D entity
     */
    class U4DVertexData{
        
    private:
       
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DVertexData();
        
        /**
         @brief Destructor for the class
         */
        ~U4DVertexData();
      
        /**
         @brief Vector containing the entity's mesh vertices
         */
        std::vector<U4DVector3n> verticesContainer;
        
        /**
         @brief Vector containing the entity's mesh normal vertices
         */
        std::vector<U4DVector3n> normalContainer;
        
        /**
         @brief Vector containing the entity's mesh uv coordinates
         */
        std::vector<U4DVector2n> uVContainer;
        
        /**
         @brief Vector containing the entity's mesh tangent vertices
         */
        std::vector<U4DVector4n> tangentContainer;
        
        /**
         @brief Vector containing the entity's mesh indices
         */
        std::vector<U4DIndex> indexContainer;
        
        /**
         @brief Vector containing the entity's mesh convex-hull vertices
         */
        std::vector<U4DVector3n> convexHullVerticesContainer;
        
        /**
         @brief Vector containing the entity's mesh bone weight vertices
         */
        std::vector<U4DVector4n> vertexWeightsContainer;
        
        /**
         @brief Vector containing the entity's mesh bone indices
         */
        std::vector<U4DVector4n> boneIndicesContainer;
        
        /**
         @brief Vector containing the entity's mesh convex-hull edges
         */
        std::vector<U4DSegment> convexHullEdgesContainer;
        
        /**
         @brief Vector containing the entity's mesh convex-hull faces
         */
        std::vector<U4DTriangle> convexHullFacesContainer;
        
        /**
         @brief Vector containing the entity's mesh PRE convex-hull vertices. These are the vertices used by the engine to compute the final convex-hull
         */
        std::vector<U4DVector3n> preConvexHullVerticesContainer;
        
        /**
         @brief 3D vector containing the dimensions of the mesh
         */
        U4DVector3n modelDimension;
        
        /**
         @brief Method which adds the entity's mesh vertices into a container
         
         @param uData Entity's mesh vertices
         */
        void addVerticesDataToContainer(U4DVector3n& uData);
        
        /**
         @brief Method which adds the entity's mesh normal vertices into a container
         
         @param uData Entity's mesh normal vertices
         */
        void addNormalDataToContainer(U4DVector3n& uData);
        
        /**
         @brief Method which adds the entity's mesh uv coordinates into a container
         
         @param uData Entity's mesh uv coordinates
         */
        void addUVDataToContainer(U4DVector2n& uData);
        
        /**
         @brief Method which adds the entity's mesh tangent vertices into a container
         
         @param uData Entity's mesh tangent vertices
         */
        void addTangetDataToContainer(U4DVector4n& uData);
        
        /**
         @brief Method which adds the entity's mesh indices into a container
         
         @param uData Entity's mesh indices
         */
        void addIndexDataToContainer(U4DIndex& uData);
        
        /**
         @brief Method which adds the entity's mesh convex-hull vertices into a container
         
         @param uData Entity's mesh convex-hull vertices
         */
        void addConvexHullVerticesToContainer(U4DVector3n& uData);
        
        /**
         @brief Method which adds the entity's mesh bone weights into a container
         
         @param uData Entity's mesh bone weights
         */
        void addVertexWeightsToContainer(U4DVector4n& uData);
        
        /**
         @brief Method which adds the entity's mesh bone indices into a container
         
         @param uData Entity's mesh bone indices
         */
        void addBoneIndicesToContainer(U4DVector4n& uData);
        
        /**
         @brief Method which adds the entity's mesh convex-hull edges into a container
         
         @param uData Entity's mesh convex-hull edges
         */
        void addConvexHullEdgesDataToContainer(U4DSegment& uData);
        
        /**
         @brief Method which adds the entity's mesh convex-hull faces into a container
         
         @param uData Entity's mesh convex-hull faces
         */
        void addConvexHullFacesDataToContainer(U4DTriangle& uData);
        
        /**
         @brief Method which adds the entity's mesh PRE convex-hull vertices into a container
         
         @param uData Entity's mesh PRE convex-hull vertices
         */
        void addPreConvexHullVerticesDataToContainer(U4DVector3n& uData);
        
        /**
         @brief Method which sets the entity's mesh dimension
         
         @param uData 3D vector holding the length, width and height of the entity's mesh
         */
        void setModelDimension(U4DVector3n& uData);
        
        /**
         @brief Method which returns the container holding the entity's mesh vertices
         
         @return Returns the entity's mesh vertices
         */
        std::vector<U4DVector3n> getVerticesDataFromContainer();
        
        /**
         @brief Method which returns the container holding the entity's mesh convex-hull vertices
         
         @return Returns the entity's mesh convex-hull vertices
         */
        std::vector<U4DVector3n> getConvexHullVerticesFromContainer();
        
        /**
         @brief Method which returns the container holding the entity's mesh convex-hull edges
         
         @return Returns the entity's mesh convex-hull edges
         */
        std::vector<U4DSegment> getConvexHullEdgesDataFromContainer();
        
        /**
         @brief Method which returns the container holding the entity's mesh convex-hull faces
         
         @return Returns the entity's mesh convex-hull faces
         */
        std::vector<U4DTriangle> getConvexHullFacesDataFromContainer();
        
        /**
         @brief Method which returns the container holding the entity's mesh PRE convex-hull vertices
         
         @return Returns the entity's mesh PRE convex-hull vertices
         */
        std::vector<U4DVector3n> getPreConvexHullVerticesDataFromContainer();
        
        /**
         @brief Method which returns the entity's mesh dimension
         
         @return 3D vector containing the entity's mesh dimension
         */
        U4DVector3n getModelDimension();
    };
    
}

#endif /* defined(__UntoldEngine__U4DVertexData__) */
