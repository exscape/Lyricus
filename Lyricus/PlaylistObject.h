//
//  RootLevelObject.h
//  NSOutlineView
//
//  Created by Thomas Backman on 3/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iTunes.h"

@interface PlaylistObject : NSObject {
@private
	iTunesPlaylist *playlist;
	NSMutableArray *children;
    
}
- (id)initWithPlaylist:(iTunesPlaylist *)pl;
-(void) addChild:(PlaylistObject *)pl;

@property (retain) iTunesPlaylist *playlist;
@property (retain, readonly) NSMutableArray *children;

@end
