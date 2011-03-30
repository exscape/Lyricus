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
@synthesize name;
@synthesize smart;
@synthesize specialKind;

- (id)init {
	return nil;
}

- (id)initWithPlaylist:(iTunesPlaylist *)pl {
	self = [super init];
	if (self) {
		playlist = pl;
		children = [[NSMutableArray alloc] init];
		name = [[pl name] copy];
		specialKind = [pl specialKind];
		if ([pl respondsToSelector:@selector(smart)] &&
			[pl performSelector:@selector(smart)]) {
			smart = YES;
		}
		else
			smart = NO;
	}
	
	return self;
}
-(BOOL) isRootItem {
	return ([[playlist parent] get] == nil);
}

-(void) addChild:(PlaylistObject *)pl {
	[children addObject:pl];
}

-(NSString *)description {
	return [playlist name];
}

- (void)dealloc {
    [super dealloc];
}

@end