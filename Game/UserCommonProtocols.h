//
//  UserCommonProtocols.h
//  UntoldEngine
//
//  Created by Harold Serrano on 10/16/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef UserCommonProtocols_h
#define UserCommonProtocols_h

typedef enum{
    
    kShooting,
    kAiming,
    kCollided,
    kHit,
    kFlying,
    kSelfDestroy,
    kNull
    
}GameEntityState;

typedef enum{
    
    kTank=1,
    kAirplane=2,
    kBullet=3,
    kAntiaircraft=4,
    kEnemy=-10,
    kAllies=-11
    
}GameEntityCollision;


#endif /* UserCommonProtocols_h */
