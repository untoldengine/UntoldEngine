//
//  CommonProtocols.h
//  MVCTemplateV001
//
//  Created by Harold Serrano on 5/5/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef MVCTemplateV001_CommonProtocols_h
#define MVCTemplateV001_CommonProtocols_h

#include <vector>
#include "U4DDualQuaternion.h"
#include "U4DPoint3n.h"
#include "U4DTriangle.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    
    /**
     @brief The TOUCHSTATE enum holds the different touch states
     */
    typedef enum {
        
        /**
         @brief Touch event began
         */
        rTouchesBegan,
        
        /**
         @brief Touch event moved
         */
        rTouchesMoved,
        
        /**
         @brief Touch event ended
         */
        rTouchesEnded,
        
        /**
         @brief Touch event is null
         */
        rTouchesNull
        
    }TOUCHSTATE;

    /**
     @brief The SPRITEDATA structure holds sprites information
     */
    typedef struct{
        
        /**
         @brief Sprite name
         */
        const char* name;
        
        /**
         @brief Sprite x-coordinate position
         */
        float x;
        
        /**
         @brief Sprite y-coordinate position
         */
        float y;
        
        /**
         @brief Sprite width
         */
        int width;
        
        /**
         @brief Sprite height
         */
        int height;
        
    }SPRITEDATA;


    /**
     @brief The SPRITEANIMATION structure holds sprite animation data
     */
    typedef struct {
        
        /**
         @brief Vector containing the names of the sprites to be used in the animation
         */
        std::vector<const char*> animationSprites;
        
        /**
         @brief Sprite animation delay
         */
        float delay;
        
    }SPRITEANIMATIONDATA;


    /**
     @brief The FONTDATA structure holds font character data
     */
    typedef struct{
        
        /**
         @brief Font character ID
         */
        int ID;
        
        /**
         @brief Font character x-coordinate position
         */
        float x;
        
        /**
         @brief Font character y-coordinate position
         */
        float y;
        
        /**
         @brief Font character width
         */
        float width;
        
        /**
         @brief Font character height
         */
        float height;
        
        /**
         @brief Font character x-offset position
         */
        float xoffset;
        
        /**
         @brief Font character y-offset position
         */
        float yoffset;
        
        /**
         @brief Font character x-advance
         */
        float xadvance;
        
        /**
         @brief Size of font
         */
        int infoFontSize;
        
        /**
         @brief Font character letter name
         */
        const char *letter;
        
    }FONTDATA;

    /**
     @brief The TEXTDATA structure holds text information
     */
    typedef struct{
        /**
         @brief Text x-coordinate position
         */
        float x;
        
        /**
         @brief Text y-coordinate position
         */
        float y;
        
        /**
         @brief Text width
         */
        float width;
        
        /**
         @brief Text height
         */
        float height;
        
        /**
         @brief Text x-offset position
         */
        float xOffset;
        
        /**
         @brief Text y-offset position
         */
        float yOffset;
        
        /**
         @brief Text x-advance
         */
        float xAdvance;
        
        /**
         @brief Text letter name
         */
        const char* letter;
    }TEXTDATA;

    /**
     @brief The KEYFRAMEDATA structure holds 3D animation keyframe data
     */
    typedef struct{
        /**
         @brief Keyframe name
         */
        std::string name;
        
        /**
         @brief Keyframe time value
         */
        float time;
        
        /**
         @brief 3D animation space transform-orientation/translation of every armature bone in keyframe
         */
        U4DDualQuaternion animationSpaceTransform;
        
    }KEYFRAMEDATA;

    /**
     @brief The ANIMATIONDATA structure holds 3D animation data
     */
    typedef struct{
      
        /**
         @brief 3D animation name
         */
        std::string name;
        
        /**
         @brief 3D animation keyframes
         */
        std::vector<KEYFRAMEDATA> keyframes;
        
    }ANIMATIONDATA;
    
    /**
     @brief The PARTICLESYSTEMTYPE enum holds data required by the particle system type
     */
    typedef enum{
        
        LINEAREMITTER,
        TORUSEMITTER,
        SPHERICALEMITTER
        
    }PARTICLESYSTEMTYPE;
    
    /**
     @brief The PARTICLESYSTEMDATA structure holds data required by the particle system
     */
    typedef struct{
        
        U4DVector3n particleStartColor;
        
        U4DVector3n particleEndColor;
        
        U4DVector3n particleStartColorVariance;
        
        U4DVector3n particleEndColorVariance;
        
        U4DVector3n particlePositionVariance;
        
        U4DVector3n particleEmitAngle;
        
        U4DVector3n particleEmitAngleVariance;
        
        /**
         @brief Distance from the center of the torus to the center of the tube
         */
        float torusMajorRadius=15.0;
        
        /**
         @brief Radius of the torus tube
         */
        float torusMinorRadius=5.0;
        
        /**
         @brief Radius of the sphere
         */
        float sphereRadius=2.0;
        
        float particleLife=1.0;
        
        float particleSpeed;
        
        int numberOfParticlesPerEmission=1;
        
        int maxNumberOfParticles=50;
        
        float emissionRate=1.0;
        
        bool emitContinuously;
        
        const char* texture="particle.png";
        
        U4DVector3n gravity;
        
        int particleSystemType=0;
        
        float particleSize=0.5;
        
        bool enableNoise=false;
        
        //Noise frequency. Possible values are 1,2,4,8,16,32
        float noiseDetail=4.0;
        
        bool enableAdditiveRendering=true;
        
    }PARTICLESYSTEMDATA;
    
    /**
     @brief The ENTITYTYPE enumeration holds the type of an entity
     */
    typedef enum{
        
        /**
         @brief Entity represents a light entity
         */
        LIGHT,
        
        /**
         @brief Entity represents a 3D model entity
         */
        MODEL,
        
        /**
         @brief Entity represents a camera entity
         */
        CAMERA,
        
        /**
         @brief Entity is a 3D parent model entity
         */
        PARENT,
        
        /**
         @brief Entity of a 3D model with no shadows enabled
         **/
        MODELNOSHADOWS,
        
        /**
         @brief Entity represents an input controller
         */
        CONTROLLERINPUT
        
    }ENTITYTYPE;


    /**
     @brief The SIMPLEXDATA structure holds data representing a simplex support point and the Minkowski difference
     */
    typedef struct{
        
        /**
         @brief Simplex Support 3D point
         */
        U4DPoint3n sa;
        
        /**
         @brief Simplex Support 3D point
         */
        U4DPoint3n sb;
        
        /**
         @brief 3D point representing a Minkowski difference
         */
        U4DPoint3n minkowskiPoint;
        
    }SIMPLEXDATA;
    
    /**
     @brief The POLYTOPEVERTEX structure holds a polytope vertex representation
     */
    typedef struct{
        
        /**
         @brief 3D vertex representing the polytope vertex
         */
        U4DVector3n vertex;
        
    }POLYTOPEVERTEX;

    /**
     @brief The POLYTOPEEDGES structure holds a polytope edge representation
     */
    typedef struct{
        
        /**
         @brief 3D segment representing a polytope segment
         */
        U4DSegment segment;
        
    }POLYTOPEEDGES;
    
    /**
     @brief The POLYTOPEFACES structure holds a polytope face representation
     */
    typedef struct{
        
        /**
         @brief 3D triangle representing a polytope face
         */
        U4DTriangle triangle;
        
    }POLYTOPEFACES;
    
    /**
     @brief The CONVEXHULL structure holds data representing vertices, edges and faces for a computed convex-hull
     */
    typedef struct{
        /**
         @brief Vector holding convex-hull vertices data
         */
        std::vector<POLYTOPEVERTEX> vertex;
        
        /**
         @brief Vector holding convex-hull edges data
         */
        std::vector<POLYTOPEEDGES> edges;
        
        /**
         @brief Vector holding convex-hull faces data
         */
        std::vector<POLYTOPEFACES> faces;
        
        /**
         @brief Boolean variable which informs if the computed convex-hull is valid
         */
        bool isValid;
        
    }CONVEXHULL;
    
    /**
     @brief The COLLISIONMANIFOLDONODE structure holds collision manifold informaiton such as contact points, collision normal vector and closest collision points
     */
    typedef struct{
        
        /**
         @brief Collision contact points
         */
        std::vector<U4DVector3n> contactPoints;
        
        /**
         @brief Collision normal-vector
         */
        U4DVector3n normalCollisionVector;
        
        /**
         @brief Closest collision points
         */
        U4DPoint3n collisionClosestPoint;
        
        /**
         @brief Angle of collision between normal planes (reference and incident plane)
         */
        float referenceAndIncidentPlaneAngle;
        
        
    }COLLISIONMANIFOLDONODE;
    
    //CONVEX HULL STRUCTURES
    typedef struct CONVEXHULLVERTEXSTRUCT CONVEXVERTEX;
    typedef CONVEXVERTEX *CONVEXHULLVERTEX;
    
    typedef struct CONVEXHULLEDGESTRUCT CONVEXEDGE;
    typedef CONVEXEDGE *CONVEXHULLEDGE;
    
    typedef struct CONVEXHULLFACESTRUCT CONVEXFACE;
    typedef CONVEXFACE *CONVEXHULLFACE;
    
    /**
     @brief The CONVEXHULLVERTEXSTRUCT structure holds vertices information used for the construction of the convex-hull
     */
    struct CONVEXHULLVERTEXSTRUCT{
        /**
         @brief Array containing the components of the vertex
         */
        float v[3];
        
        /**
         @brief total number of vertices
         */
        int vNum;
        
        /**
         @brief duplicate convex hull edge
         */
        CONVEXHULLEDGE duplicate;
        
        /**
         @brief Boolean variable which is used to flag the convex-hull algorithm that the vertex is on-Hull
         */
        bool onHull;
        
        /**
         @brief Boolean variable which is used to flag the convex-hull algorithm that the vertex has been processed
         */
        bool processed;
        
        /**
         @brief Pointer to the Next vertex
         */
        CONVEXHULLVERTEX next;
        
        /**
         @brief Pointer to the Previous vertex
         */
        CONVEXHULLVERTEX prev;
        
    };
    
    /**
     @brief The CONVEXHULLEDGESTRUCT structure holds edges information used during the construction of the convex-hull
     */
    struct CONVEXHULLEDGESTRUCT{
        /**
         @brief Array of faces adjacent to the edge
         */
        CONVEXHULLFACE adjFace[2];
        
        /**
         @brief Array of endpoint vertices composing the edge
         */
        CONVEXHULLVERTEX endPts[2];
        
        /**
         @brief New face in convex-hull
         */
        CONVEXHULLFACE newFace;
        
        /**
         @brief Boolean variable which informs the convex-hull algorithm that the edge should be deleted
         */
        bool shouldDelete;
        
        /**
         @brief Pointer to the the Next edge
         */
        CONVEXHULLEDGE next;
        
        /**
         @brief Pointer to the Previous edge
         */
        CONVEXHULLEDGE prev;
    };
    
    /**
     @brief The CONVEXHULLFACESTRUCT structure holds faces information used during the construction of the convex-hull
     */
    struct CONVEXHULLFACESTRUCT{
        /**
         @brief Array of edges composing the current face
         */
        CONVEXHULLEDGE edge[3];
        
        /**
         @brief Array of vertices composing the current face
         */
        CONVEXHULLVERTEX vertex[3];
        
        /**
         @brief Boolean algebra which informs the convex-hull algorithm that the face is seen by a point
         */
        bool visible;
        
        /**
         @brief Pointer to the Next face
         */
        CONVEXHULLFACE next;
        
        /**
         @brief Pointer to the Previous face
         */
        CONVEXHULLFACE prev;
    };
    
    /**
     @brief The INERTIATENSORTYPE enum holds information about the different geometrical mesh types used to calculate the Inertia Tensor
     */
    typedef enum{
        
        /**
         @brief The mesh geometry is cubic
         */
        cubicInertia,
        
        /**
         @brief The mesh geometry is spherical
         */
        sphericalInertia,
        
        /**
         @brief The mesh geometry is cylindrical
         */
        cylindricalInertia
        
    }INERTIATENSORTYPE;
    
}




#endif
