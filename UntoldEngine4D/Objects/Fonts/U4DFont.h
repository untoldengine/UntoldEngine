//
//  U4DFont.h
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DFont__
#define __UntoldEngine__U4DFont__

#include <iostream>
#include <vector>
#include "CommonProtocols.h"
#include "U4DImage.h"

namespace U4DEngine {
    
class U4DFontLoader;

}

namespace U4DEngine {
    
class U4DFont:public U4DImage{
    
private:
    
    U4DFontLoader *fontLoader;
    
    const char* text;
    
    std::vector<TextData> textContainer;
    
    float textSpacing;
    
public:
    
    U4DFont(U4DFontLoader* uFontLoader);

    ~U4DFont(){
        delete fontLoader;
       
    };
    
    U4DFont(const U4DFont& value){};
    
    U4DFont& operator=(const U4DFont& value){return *this;};
    
    const char* fontImage;
    
    void setFont();
    
    void setText(const char* uText);
    
    void draw();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DFont__) */
