//
//  GameViewController.h
//  Untold4D macOS
//
//  Created by Harold Serrano on 2/6/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <GameController/GameController.h>
#include "GameScene.h"

// Our macOS view controller.
@interface GameViewController : NSViewController
@property (nonatomic) GameScene gameScene;
@end
