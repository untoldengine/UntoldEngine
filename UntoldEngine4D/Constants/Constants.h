//
//  Constants.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/21/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef UntoldEngine_Constants_h
#define UntoldEngine_Constants_h

namespace U4DEngine {
    
    const float PI=3.141592653589793;
    const float sleepEpsilon=0.96;
    const float sleepBias=0.5;
    const float collisionDistanceEpsilon=1.0e-4f;
    const float minimumTimeOfImpact=0.8;
    const float barycentricEpsilon=1.0;
    const float timeStep=0.01;
    const float zeroEpsilon=1.0e-4f;
    const float zeroPlaneIntersectionEpsilon=1.0e-3f;
    const float impulseCollisionMinimum=0.0; //sets the minimum impulse allowed between collisions
    const float rungaKuttaCorrectionCoefficient=0.7;
    const float planeBoundaryEpsilon=0.8f; //epsilon to determine if point is inside/outside plane
    const float DEPTHSHADOWWIDTH=1024;
    const float DEPTHSHADOWHEIGHT=1024;
}

#define DegreesToRad(angle) angle*M_PI/180
#define RadToDegrees(angle) angle*180/M_PI


#endif
