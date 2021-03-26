//
//  DemoLoading.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef DemoLoading_hpp
#define DemoLoading_hpp

#include <stdio.h>
#include "U4DWorld.h"
#include "U4DImage.h"

class DemoLoading:public U4DEngine::U4DWorld {
    
private:

    U4DEngine::U4DImage *loadingBackgroundImage;
    
public:
    
    DemoLoading();
    
    ~DemoLoading();
    
    void init();
    
    void update(double dt);

    
};
#endif /* DemoLoading_hpp */
