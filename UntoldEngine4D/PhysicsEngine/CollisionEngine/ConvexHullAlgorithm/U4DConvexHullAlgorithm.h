//
//  U4DConvexHullAlgorithm.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/11/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//
//  This is a C++ implementation of Joseph O'Rourke's classic Incremental Convex Hull
//  algorithm mentioned in his book "Computation Geometry" 2nd edition.
//  In contrast to his original implementation this implementation works with floating point numbers.
//  The algorithm has been minimally modified to work with the Untold Engine by Harold Serrano

#ifndef U4DConvexHullAlgorithm_hpp
#define U4DConvexHullAlgorithm_hpp

#include <stdio.h>
#include "CommonProtocols.h"
#include "U4DVector3n.h"

/**
 @brief The U4DConvexHullAlgorithm class computes the convex-hull of a 3D model entity
 */
namespace U4DEngine {
    
    class U4DConvexHullAlgorithm{
        
    private:
        
        /**
         @brief Convex-hull vertex
         */
        CONVEXHULLVERTEX vertexHead;
        
        /**
         @brief Convex-hull edge
         */
        CONVEXHULLEDGE edgeHead;
        
        /**
         @brief Convex-hull face
         */
        CONVEXHULLFACE faceHead;
        
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DConvexHullAlgorithm();
        
        /**
         @brief Destructor for the class
         */
        ~U4DConvexHullAlgorithm();
        
        /**
         @brief Method which creates a vertex structure
         
         @return Returns a new vertex structure
         */
        CONVEXHULLVERTEX makeNullVertex();
        
        /**
         @brief Method which creates an edge structure
         
         @return Returns a new edge structure
         */
        CONVEXHULLEDGE makeNullEdge();
        
        /**
         @brief Method which creates a face structure
         
         @return Returns a new face structure
         */
        CONVEXHULLFACE makeNullFace();
        
        /**
         @brief Method which begins the construction of the convex-hull
         
         @param uVertices 3D model's vertices used to compute convex-hull
         
         @return Returns the computed Convex-Hull structure
         */
        CONVEXHULL computeConvexHull(std::vector<U4DVector3n> &uVertices);
        
        /**
         @brief Method which loads 3D model's vertices
         
         @param uVertices 3D model's vertices used to compute convex-hull
         */
        void readVertices(std::vector<U4DVector3n> &uVertices);
        
        /**
         @brief DoubleTriangle builds the initial double triangle. It first finds 3
         noncollinear points and makes two faces out of them, in opposite order.
         It then finds a fourth point that is not coplanar with that face.  The
         vertices are stored in the face structure in counterclockwise order so
         that the volume between the face and the point is negative. Lastly, the
         3 newfaces to the fourth point are constructed and the data structures
         are cleaned up.
         
         @return Returns true if no error were found during construction
         */
        bool doubleTriangle();
        
        /**
         @brief Collinear checks to see if the three points given are collinear,
         by checking to see if each element of the cross product is zero.
         
         @param a Convex-hull vertex structure
         @param b Convex-hull vertex structure
         @param c Convex-hull vertex structure
         
         @return Returns false if no collinear vertices were found
         */
        bool collinear(CONVEXHULLVERTEX a, CONVEXHULLVERTEX b, CONVEXHULLVERTEX c);
        
        /**
         @brief MakeFace creates a new face structure from three vertices (in ccw
         order).  It returns a pointer to the face.
         
         @param v0   Convex-hull vertex structure
         @param v1   Convex-hull vertex structure
         @param v2   Convex-hull vertex structure
         @param fold Convex-hull face
         
         @return Returns a convex-hull face
         */
        CONVEXHULLFACE makeFace(CONVEXHULLVERTEX v0, CONVEXHULLVERTEX v1, CONVEXHULLVERTEX v2, CONVEXHULLFACE fold);
        
        /**
         @brief ConstructHull adds the vertices to the hull one at a time.  The hull
         vertices are those in the list marked as onhull.
         
         @return Returns true if all convex-hull tests passed
         */
        bool constructHull();
        
        /**
         @brief AddOne is passed a vertex.  It first determines all faces visible from
         that point.  If none are visible then the point is marked as not
         onhull.  Next is a loop over edges.  If both faces adjacent to an edge
         are visible, then the edge is marked for deletion.  If just one of the
         adjacent faces is visible then a new face is constructed.
         
         @param p Convex-hull vertex
         
         @return Returns true if the vertex was added succesfully
         */
        bool addOne(CONVEXHULLVERTEX p);
        
        /**
         @brief VolumeSign returns the sign of the volume of the tetrahedron determined by f
         and p.  VolumeSign is +1 iff p is on the negative side of f,
         where the positive side is determined by the rh-rule.  So the volume
         is positive if the ccw normal to f points outside the tetrahedron.
         The final fewer-multiplications form is due to Bob Williamson.
         
         @param f Convex-hull face structure
         @param p Convex-hull vertex structure
         
         @return Returns the volume sign of the tetrahedron
         */
        int volumeSign(CONVEXHULLFACE f, CONVEXHULLVERTEX p);
        
        /**
         @brief MakeConeFace makes a new face and two new edges between the
         edge and the point that are passed to it. It returns a pointer to
         the new face.
         
         @param e Convex-hull edge structure
         @param p Convex-hull edge structure
         
         @return Returns a convex-hull face structure
         */
        CONVEXHULLFACE makeConeFace(CONVEXHULLEDGE e, CONVEXHULLVERTEX p);
        
        /**
         @brief MakeCcw puts the vertices in the face structure in counterclock wise
         order.  We want to store the vertices in the same
         order as in the visible face.  The third vertex is always p.
         
         @param f Convex-hull face struct
         @param e Convex-hull edge struct
         @param p Convex-hull point struct
         */
        void makeCcw(CONVEXHULLFACE f,CONVEXHULLEDGE e,CONVEXHULLVERTEX p);
        
        /**
         @brief Method which swaps the convex-hull edges
         
         @param t Convex-hull edge struct
         @param x Convex-hull edge struct
         @param y Convex-hull edge struct
         */
        void swapEdges(CONVEXHULLEDGE t, CONVEXHULLEDGE x, CONVEXHULLEDGE y);
        
        /**
         @brief Method which calls cleanEdges, cleanFaces and CleanVertices methods
         
         @param pvnext Convex-hull vertex struct
         */
        void cleanUp(CONVEXHULLVERTEX *pvnext);
        
        /**
         @brief Method which determines which edges to delete
         */
        void cleanEdges();
        
        /**
         @brief Method which determines which faces to delete
         */
        void cleanFaces();
        
        /**
         @brief Method which determines which vertices to delete
         
         @param pvnext Convex-hull edge struct
         */
        void cleanVertices(CONVEXHULLVERTEX *pvnext);

        /**
         @brief Method which deletes edges marked for deletion
         
         @param p Convex-hull edge to delete
         */
        void deleteEdge(CONVEXHULLEDGE p);
        
        /**
         @brief Method which deletes faces marked for deletion
         
         @param p Convex-hull face to delete
         */
        void deleteFace(CONVEXHULLFACE p);
        
        /**
         @brief Method which deletes vertices marked for deletion
         
         @param p Convex-hull vertex to delete
         */
        void deleteVertex(CONVEXHULLVERTEX p);
        
        /**
         @brief Method which checks if the convex-hull is valid
         
         @return Returns true if the convex-hull is valie
         */
        bool checkIfConvexHullIsValid();
        
        /**
         @brief Method which checks if convex-hull passed the Consistency test
         
         @return Returns true if convex-hull passed the Consistency test
         */
        bool checkIfConsistencyPassed();
        
        /**
         @brief Method which checks if convex-hull passed the Convexity test
         
         @return Returns true if convex-hull passed the Convexity test
         */
        bool checkIfConvexityPassed();
        
        /**
         @brief Method which checks if convex-hull passed the Euler Formula test
         
         @return Returns true if convex-hull passed the Euler Formula test
         */
        bool checkIfEulerFormulaPassed();
        
        /**
         @brief Method which loads computed convex-hull vertices into the convex-hull structure
         
         @param uConvexHull Convex-hull structure which will receive the data
         */
        void loadComputedCHVertices(CONVEXHULL &uConvexHull);
        
        /**
         @brief Method which loads computed convex-hull edges into the convex-hull structure
         
         @param uConvexHull Convex-hull structure which will receive the data
         */
        void loadComputedCHEdges(CONVEXHULL &uConvexHull);
        
        /**
         @brief Method which loads computed convex-hull faces into the convex-hull structure
         
         @param uConvexHull Convex-hull structure which will receive the data
         */
        void loadComputedCHFaces(CONVEXHULL &uConvexHull);
    };
}

#endif /* U4DConvexHullAlgorithm_hpp */
