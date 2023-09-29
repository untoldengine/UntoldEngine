//
//  U4DJsonReader.hpp
//  UntoldEnginePro
//
//  Created by Harold Serrano on 9/8/23.
//

#ifndef U4DJsonReader_hpp
#define U4DJsonReader_hpp

#include <stdio.h>
#include <vector>
#include <string>
#include "U4DComponents.h"

namespace U4DEngine {
        
    std::vector<VoxelData> readVoxelFile(std::string fileName);

}


#endif /* U4DJsonReader_hpp */
