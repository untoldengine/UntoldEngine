//
//  U4DConvexHullAlgorithm.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/11/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//  Algorithm implemented from "Computational Geometry in C" (Second Edition)
//  Convex Hull Algorithm created by Joseph O'Rourke.
//  Algorithm has been minimally modified to work with the Untold Engine by Harold Serrano

#ifndef U4DConvexHullAlgorithm_hpp
#define U4DConvexHullAlgorithm_hpp

#include <stdio.h>
#include "CommonProtocols.h"

namespace U4DEngine {
    
    class U4DConvexHullAlgorithm{
        
    private:
        CONVEXHULLVERTEX vertexHead;
        CONVEXHULLEDGE edgeHead;
        CONVEXHULLFACE faceHead;
        
    public:
        U4DConvexHullAlgorithm();
        ~U4DConvexHullAlgorithm();
        
        CONVEXHULLVERTEX makeNullVertex();
        CONVEXHULLEDGE makeNullEdge();
        CONVEXHULLFACE makeNullFace();
        
        void doubleTriangle();
        bool collinear(CONVEXHULLVERTEX a, CONVEXHULLVERTEX b, CONVEXHULLVERTEX c);
        CONVEXHULLFACE makeFace(CONVEXHULLVERTEX v0, CONVEXHULLVERTEX v1, CONVEXHULLVERTEX v2, CONVEXHULLFACE fold);
        void constructHull();
        bool addOne(CONVEXHULLVERTEX p);
        int volumeSign(CONVEXHULLFACE f, CONVEXHULLVERTEX p);
        CONVEXHULLFACE makeConeFace(CONVEXHULLEDGE e, CONVEXHULLVERTEX p);
        void makeCcw(CONVEXHULLFACE f,CONVEXHULLEDGE e,CONVEXHULLVERTEX p);
        void swapEdges(CONVEXHULLEDGE t, CONVEXHULLEDGE x, CONVEXHULLEDGE y);
        void cleanUp(CONVEXHULLVERTEX *pvnext);
        void cleanEdges();
        void cleanFaces();
        void cleanVertices(CONVEXHULLVERTEX *pvnext);
        void deleteEdge(CONVEXHULLEDGE p);
        void deleteFace(CONVEXHULLFACE p);
        void deleteVertex(CONVEXHULLVERTEX p);
    };
}

#endif /* U4DConvexHullAlgorithm_hpp */
