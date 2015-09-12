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

namespace U4DEngine {
/**
 *  Class in charge of 3D point
 */
class U4DPoint3n{

private:
    
public:
    
    /**
     *  x-component
     */
    float x;
    
    /**
     *  y-component
     */
    float y;
    
    /**
     *  z-component
     */
    float z;
    
    /**
     *  Constructor
     */
    U4DPoint3n(){}
    
    /**
     *  Constructor
     *
     *  @param nx     x-component
     *  @param ny     y-component
     *  @param nz     z-component
     */
    U4DPoint3n(float nx,float ny,float nz):x(nx),y(ny),z(nz){};
    
    /**
     *  Destructor
     */
    ~U4DPoint3n(){};
    
    /**
     *  Copy constructor
     */
    U4DPoint3n(const U4DPoint3n& a):x(a.x),y(a.y),z(a.z){};
    
    /**
     *  Copy assignment
     */
    inline U4DPoint3n& operator=(const U4DPoint3n& a){
    
       x=a.x;
       y=a.y;
       z=a.z;
       
        return *this;
    
    };
    
    
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
    
    void convertVectorToPoint(U4DVector3n& v);
    
    float magnitude();

    float magnitudeSquare();
    
    U4DVector3n toVector();
    
    void show();
    
};

}

#endif /* defined(__UntoldEngine__U4DPoint3n__) */
