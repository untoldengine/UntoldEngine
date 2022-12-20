//
//  U4DRenderPolygon.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/2/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderPolygon_hpp
#define U4DRenderPolygon_hpp

#include <stdio.h>
#include "U4DRenderGeometry.h"
#include "U4DMesh.h"

namespace U4DEngine{

class U4DRenderPolygon:public U4DRenderGeometry {
    
private:
    U4DMesh *u4dObject;
public:
    
    U4DRenderPolygon(U4DMesh *uU4DGeometricObject);
    
    ~U4DRenderPolygon();
    
    void render(id <MTLRenderCommandEncoder> uRenderEncoder);
};

}

#endif /* U4DRenderPolygon_hpp */
