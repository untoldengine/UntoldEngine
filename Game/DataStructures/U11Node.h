//
//  U11Node.h
//  UntoldEngine
//
//  Created by Harold Serrano on 3/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11Node_h
#define U11Node_h

#include "U11Player.h"

struct U11Node {
    
    U11Player *player;
    float data;
    U11Node *leftChild;
    U11Node *rightChild;
    
};


#endif /* U11Node_h */
