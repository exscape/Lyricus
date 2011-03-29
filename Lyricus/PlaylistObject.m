//
//  RootLevelObject.m
//  NSOutlineView
//
//  Created by Thomas Backman on 3/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PlaylistObject.h"


@implementation PlaylistObject

@synthesize playlist;
@synthesize children;

- (id)init {
    self = [super init];
    if (self) {
		self.playlist = nil;
		children = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (id)initWithPlaylist:(iTunesPlaylist *)pl {
	self = [super init];
	if (self) {
		self.playlist = pl;
		children = [[NSMutableArray alloc] init];
	}
	
	return self;
}

-(void) addChild:(PlaylistObject *)pl {
	[children addObject:pl];
}

-(BOOL) isRootItem {
	return ([playlist parent] == nil);
}

-(NSString *)description {
	return [playlist name];
}

- (void)dealloc {
    [super dealloc];
}

@end