//
//  CommonProtocols.h
//  MVCTemplateV001
//
//  Created by Harold Serrano on 5/5/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef MVCTemplateV001_CommonProtocols_h
#define MVCTemplateV001_CommonProtocols_h

#include <vector>
#include <string>

namespace U4DEngine {
    typedef void (*callback)(void);

struct KeyState {
    bool wPressed = false;
    bool aPressed = false;
    bool sPressed = false;
    bool dPressed = false;
    bool spacePressed = false;
    bool shiftPressed = false;
    bool ctrlPressed = false;
    bool altPressed = false;
    bool leftMousePressed = false;
    bool rightMousePressed = false;
    bool middleMousePressed = false;
    // Add more key states as needed
};
}

#endif
