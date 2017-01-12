//
//  GameAsset.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/30/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef GameAsset_hpp
#define GameAsset_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class GameAsset:public U4DEngine::U4DGameObject {
    
    
    
public:
    GameAsset(){};
    ~GameAsset(){};
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};

#endif /* GameAsset_hpp */
