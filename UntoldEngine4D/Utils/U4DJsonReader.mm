//
//  U4DJsonReader.cpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 9/8/23.
//

#include "U4DJsonReader.h"
#import <Foundation/Foundation.h>

namespace U4DEngine {

std::vector<VoxelData> readVoxelFile(std::string fileName) {
     
    NSString* pathToFile = [NSString stringWithUTF8String:fileName.c_str()];
    
    NSString* pathFileName = [[pathToFile lastPathComponent] stringByDeletingPathExtension];
    NSString* pathExtension = [pathToFile pathExtension];
    
    NSString *fileURL=[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@", pathFileName] ofType:pathExtension];
    
    if(fileURL==nil)
        fileURL=[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@", @"gameboyvoxel"] ofType:@"json"];
    
    NSURL *url=[NSURL fileURLWithPath:fileURL];

    NSError* error;
    NSData* jsonData = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&error];

    if (jsonData) {
        NSArray* dataArray = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
        
        if (dataArray) {
            std::vector<VoxelData> voxelDataArray;

            for (NSDictionary* dataDict in dataArray) {
                VoxelData voxelData; // Assuming VoxelData is a C++ struct
                
                voxelData.guid = [(NSNumber*)dataDict[@"guid"] unsignedIntValue];
                
                voxelData.color.x=[(NSNumber*)dataDict[@"color"][0] floatValue] ;
                voxelData.color.y=[(NSNumber*)dataDict[@"color"][1] floatValue] ;
                voxelData.color.z=[(NSNumber*)dataDict[@"color"][2] floatValue] ;
                
                voxelData.material.x=[(NSNumber*)dataDict[@"material"][0] floatValue] ;
                voxelData.material.y=[(NSNumber*)dataDict[@"material"][1] floatValue] ;
                voxelData.material.z=[(NSNumber*)dataDict[@"material"][2] floatValue] ;
                
                
                voxelDataArray.push_back(voxelData);
            }

            return voxelDataArray;
        } else {
            NSLog(@"Error parsing JSON data: %@", [error localizedDescription]);
            return;
        }
    } else {
        NSLog(@"Error reading file: %@", [error localizedDescription]);
        return;
    }

    return std::vector<VoxelData>();
}


}
