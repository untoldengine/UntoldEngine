//
//  U4DSerializer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/1/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSerializer_hpp
#define U4DSerializer_hpp

#include <stdio.h>
#include <string>
#include <vector>
#include "CommonProtocols.h"

namespace U4DEngine {

    class U4DSerializer {

    private:
        
        static U4DSerializer *instance;
        
        std::vector<ENTITYSERIALIZEDATA> entitySerializeDataContainer;
        std::vector<PLAYERATTRIBUTES> attributeSerializeDataContainer;
        
    protected:
        
        U4DSerializer();
        
        ~U4DSerializer();
        
    public:
        
        static U4DSerializer *sharedInstance();
        
        bool serialize(std::string uFileName);
        
        void prepareEntities();
        
        bool convertEntitiesToBinary(std::string uFileName);
        
        bool deserialize(std::string uFileName);
        
        bool convertBinaryToEntities(std::string uFileName);
        
        void unloadEntities();
        
        bool serializeAttributes(std::string uFileName);
        
        void prepareAttributes();
        
        bool convertAttributesToBinary(std::string uFileName);
        
        bool deserializeAttributes(std::string uFileName);
        
        bool convertBinaryToAttributes(std::string uFileName);
        
        void unloadAttributes();
        
    };

}
#endif /* U4DSerializer_hpp */
