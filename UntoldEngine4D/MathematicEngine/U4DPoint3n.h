//
//  U4DPoint3n.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DPoint3n__
#define __UntoldEngine__U4DPoint3n__

#include <iostream>

namespace U4DEngine {
    
class U4DVector3n;

}

/**
 @brief The U4DPoint3n implements a 3D point representation in space.
 */
namespace U4DEngine {

class U4DPoint3n{

private:
    
public:
    
    /**
     @brief x-component
     */
    float x;
    
    /**
     @brief y-component
     */
    float y;
    
    /**
     @brief z-component
     */
    float z;
    
    /**
     @brief Contructor which creates a default 3D point. That is, its componets are initialized to zero.
     */
    U4DPoint3n();
    
    /**
     @brief Contructor which creates a default 3D point with the given x, y and z component values.
     
     @param nx x-component
     @param ny y-component
     @param nz z-component
     */
    U4DPoint3n(float nx,float ny,float nz);
    
    /**
     @brief Destructor for the class
     */
    ~U4DPoint3n();
    
    /**
     @brief Copy constructor for the class
     @param a 3D point to copy to
     */
    U4DPoint3n(const U4DPoint3n& a);
    
    /**
     @brief Copy constructor for the class
     
     @param a 3D point to copy to
     
     @return returns a copy of the 3D point
     */
    U4DPoint3n& operator=(const U4DPoint3n& a);
    
    /**
     @brief Method which compares if two 3D points are equal
     
     @param a 3D point to compare with
     
     @return Returns true if two points are equal
     */
    bool operator==(const U4DPoint3n& a);
    
    bool operator!=(const U4DPoint3n& a);
    
    /**
     *  Add points
     *
     *  @param v point
     */
    void operator+=(const U4DPoint3n& v);
    
    /**
     *  Add points
     *
     *  @param v point
     *
     *  @return point addition
     */
    U4DPoint3n operator+(const U4DPoint3n& v)const;
    
    /**
     *  Point subraction
     *
     *  @param p point
     *
     *  @return vector
     */
    U4DVector3n operator-(const U4DPoint3n& p)const;
    
    U4DPoint3n operator*(const float s)const;
    
    /**
     *  Distance between points
     *
     *  @param a point A
     *  @param b point B
     *
     *  @return Distance between points
     */
    float distanceBetweenPoints(U4DPoint3n& v);
    
    float distanceSquareBetweenPoints(U4DPoint3n& v);
    
    void convertVectorToPoint(U4DVector3n& v);
    
    float magnitude();

    float magnitudeSquare();
    
    void zero();
    
    U4DVector3n toVector();
    
    void show();
    
};

}

#endif /* defined(__UntoldEngine__U4DPoint3n__) */
