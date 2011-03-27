//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Cocoa/Cocoa.h>
#import "TBLyricSite.h"

@interface TBSongmeanings : TBLyricSite {
	TBUtil *util;
}

//
// Sorted by order of invocation
//
-(NSString *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist withBulk:(BOOL)bulk error:(NSError **)error;

// Private methods
-(NSString *)getURLForArtist:(NSString *) artist error:(NSError **)error;
-(NSString *)getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)artistURL error:(NSError **)error;
-(NSString *)extractLyricsFromURL:(NSString *)url error:(NSError **)error;

@end
