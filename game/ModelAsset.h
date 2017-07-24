//
//  ModelAsset.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef ModelAsset_hpp
#define ModelAsset_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class ModelAsset:public U4DEngine::U4DGameObject {
    
private:
    
public:
    
    ModelAsset();
    
    ~ModelAsset();
    
    void init(const char* uModelName, const char* uBlenderFile, const char* uTextureNormal);
    
    void update(double dt);
    
};
#endif /* ModelAsset_hpp */
