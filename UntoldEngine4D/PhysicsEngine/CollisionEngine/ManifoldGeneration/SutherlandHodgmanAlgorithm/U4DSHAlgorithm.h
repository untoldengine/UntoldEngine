//
//  U4DSHAlgorithm.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/18/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSHAlgorithm_hpp
#define U4DSHAlgorithm_hpp

#include <stdio.h>
#include "U4DManifoldGeneration.h"

namespace U4DEngine {
    class U4DSegment;
    class U4DTriangle;
}

namespace U4DEngine {
    
    /**
     @brief The CONTACTFACES structure holds collision polygon faces information
     */
    typedef struct{
        
        /**
         @brief Face of polygon
         */
        U4DTriangle triangle;
        
        /**
         @brief Distance to plane
         */
        float distance;
        
        /**
         @brief Dot product parallel to plane
         */
        float dotProduct;
        
    }CONTACTFACES;
    
    /**
     @brief The CONTACTEDGE structure holds collision polygon segment information
     */
    typedef struct{
        
        /**
         @brief Segment of polygon
         */
        U4DSegment segment;
        
        /**
         @brief Is the polygon segment a duplicate
         */
        bool isDuplicate;
        
        /**
         @brief Normal vector to polygon segment
         */
        U4DVector3n normal;
        
        /**
         @brief Is segment a reference segment
         */
        bool isReference;
        
        /**
         @brief Dot product parallel to segment
         */
        float dotProduct;
        
        /**
         @brief Distance to segment
         */
        float distance;
        
    }CONTACTEDGE;
    
    /**
     @brief The EDGEDIRECTION enum holds edge direction information. This information is used to properly clipped a polygon
     */
    typedef enum{
        
        /**
         @brief Segment direction goes from INSIDE of plane to INSIDE of plane
         */
        inToIn=0,
        
        /**
         @brief Segment direction goes from INSIDE of plane to OUTSIDE of plane
         */
        inToOut=1,
        
        /**
         @brief Segment direction goes from OUTSIDE of plane to INSIDE of plane
         */
        outToIn=2,
        
        /**
         @brief Segment direction goes from OUTSIDE of plane to OUTSIDE of plane
         */
        outToOut=3,
        
        /**
         @brief Segment direction is in plane boundary
         */
        inBoundary=4
        
    }EDGEDIRECTION;
    
    /**
     @brief The POINTLOCATION enum holds location of a segment point with respect to a plane
     */
    typedef enum{
        
        /**
         @brief Point is insdie the plane
         */
        insidePlane=1,
        
        /**
         @brief Point is outside the plane
         */
        outsidePlane=-1,
        
        /**
         @brief Point lies in plane boundary
         */
        boundaryPlane=0
    }POINTLOCATION;
    
    /**
     @brief The POINTINFORMATION structure holds segment point information
     */
    typedef struct{
        
        /**
         @brief A segment 3D point
         */
        U4DPoint3n point;
        
        /**
         @brief Point location with respect to plane
         */
        POINTLOCATION location;
    }POINTINFORMATION;
    
    /**
     @brief The CONTACTEDGEINFORMATION structure holds contact edge information
     */
    typedef struct{
        
        /**
         @brief Contact segment
         */
        U4DSegment contactSegment;
        
        /**
         @brief Contact segment direction with respect to a plane
         */
        EDGEDIRECTION direction;
    }CONTACTEDGEINFORMATION;
    
}

namespace U4DEngine {
    
    /**
     @brief The U4DSHAlgorithm class is in charge of implementing the Sutherland-Hodgman algorithm
     */
    class U4DSHAlgorithm:public U4DManifoldGeneration{
        
    private:
        
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DSHAlgorithm();
        
        /**
         @brief Destructor for the class
         */
        ~U4DSHAlgorithm();
        
        /**
         @brief Method which determines the collision contact manifold. It retrieves the collision contact points of the collision.
         
         @param uModel1                3D model entity
         @param uModel2                3D model entity
         @param uQ                     Simplex Data set
         @param uCollisionManifoldNode Collision Manifold node
         
         @return Returns true if the collision contact points were successfully computed
         */
        bool determineContactManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<SIMPLEXDATA> uQ, COLLISIONMANIFOLDONODE &uCollisionManifoldNode);
        
        /**
         @brief Method which determines the collision manifold. It computes the collision planes
         
         @param uModel1                3D model entity
         @param uModel2                3D model entity
         @param uQ                     Simplex Data set
         @param uCollisionManifoldNode Collision Manifold node
         */
        void determineCollisionManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<SIMPLEXDATA> uQ,COLLISIONMANIFOLDONODE &uCollisionManifoldNode);
        
        /**
         @brief Method which clips polygons
         
         @param uReferencePolygons Container holding the reference segments
         @param uIncidentPolygons  Container holding the incidient segments
         
         @return Returns a container holding clipped sigments
         */
        std::vector<U4DSegment> clipPolygons(std::vector<CONTACTEDGE>& uReferencePolygons, std::vector<CONTACTEDGE>& uIncidentPolygons);
        
        /**
         @brief Method which computes the most parallel faces to collision plane
         
         @param uModel 3D model entity
         @param uPlane Collision plane
         
         @return Returns the most parallel faces to plane
         */
        std::vector<CONTACTFACES> mostParallelFacesToPlane(U4DDynamicModel* uModel, U4DPlane& uPlane);
        
        /**
         @brief Method which projects polygon faces to collision plane
         
         @param uFaces Polygon faces
         @param uPlane Collision plane
         
         @return Returns a container holding the projected polygon faces onto the collision plane
         */
        std::vector<U4DTriangle> projectFacesToPlane(std::vector<CONTACTFACES>& uFaces, U4DPlane& uPlane);
        
        /**
         @brief Method which extracs edges from a polygon face
         
         @param uFaces Polygon face
         @param uPlane collision plane
         
         @return Returns a container holding the edges extracted from a polygon face
         */
        std::vector<CONTACTEDGE> getEdgesFromFaces(std::vector<U4DTriangle>& uFaces, U4DPlane& uPlane);
        
        /**
         @brief Method which computes if the 3D entity center of mass is within the boundary of the reference plane
         
         @param uModel             3D model entity
         @param uReferencePolygons Reference polygon
         
         @return Returns true if the 3D entity center of mass is within the boundary of the reference plane
         */
        bool isCenterOfMassWithinReferencePlane(U4DDynamicModel* uModel,std::vector<CONTACTEDGE>& uReferencePolygons);
        
    };
    
}


#endif /* U4DSHAlgorithm_hpp */
