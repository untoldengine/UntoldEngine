//
//  U4DRenderFont.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DRenderFont_hpp
#define U4DRenderFont_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include "U4DRenderImage.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"


namespace U4DEngine {
    
    class U4DRenderFont:public U4DRenderImage {
        
    private:
        
        U4DImage *u4dObject;
        
    public:
        
        U4DRenderFont(U4DImage *uU4DImage);
        
        ~U4DRenderFont();
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void setTextDimension(U4DVector3n &uFontPositionOffset, U4DVector2n &uFontUV, int uTextCount, float uTextWidth,float uTextHeight, float uAtlasWidth,float uAtlasHeight);
        
        void updateRenderingInformation();
        
        void modifyRenderingInformation();
        
        void clearModelAttributeData();
    };
    
}

#endif /* U4DRenderFont_hpp */
