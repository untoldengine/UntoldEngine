//
//  ModelAsset.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/23/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef ModelAsset_hpp
#define ModelAsset_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "CommonProtocols.h"

class ModelAsset:public U4DEngine::U4DGameObject {
    
private:
    

public:
    
    ModelAsset();
    
    ~ModelAsset();
    
    bool init(const char* uModelName, const char* uBlenderFile);
    
    void update(double dt);
    
    void setType();
    
    
    
};
#endif /* ModelAsset_hpp */
