//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "iTunesHelper.h"

@implementation iTunesHelper

#pragma mark -
#pragma mark init stuff

static iTunesHelper *sharediTunesHelper = nil;

+(iTunesHelper *)sharediTunesHelper {
    @synchronized(self) {
        if (sharediTunesHelper == nil) {
            sharediTunesHelper = [[iTunesHelper alloc] init];
        }
    }
    return sharediTunesHelper;
}

+(id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharediTunesHelper == nil) {
            sharediTunesHelper = [super allocWithZone:zone];
            return sharediTunesHelper;
        }
    }
    return sharediTunesHelper;
}

- (id)copyWithZone:(NSZone *)zone { 
	return self; 
} 


-(id) init {
    self = [super init];
	if (self) {
		iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
	}
	
	return self;
}

-(BOOL)currentTrackIsStream {
	if (![self initiTunes])
		return NO; // Ugh.
	
	@try {
		return ([iTunes currentStreamTitle] != nil);
	}
	@catch (NSException *e) { return NO; }
	
	// Silence warning
	return NO;
}

-(BOOL) initiTunes {
	@try {
		if (iTunes == nil)
			iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
		
		if (![iTunes isRunning]) {
			return NO;
		}
	}
	@catch (NSException *e) { return NO; }
	
	return YES;
}

#pragma mark -
#pragma mark Playlist stuff

-(NSArray *)getAllPlaylists {
		NSMutableArray *playlistArray = [[NSMutableArray alloc] init];
		
		if (![self initiTunes])
			return nil;
		
		@try {
			SBElementArray *pls = [[[iTunes sources] objectAtIndex:0] playlists];
			
			for (iTunesPlaylist *pl in pls) {
				if (!pl)
					continue;
				int kind = [pl specialKind];
				if (kind == iTunesESpKNone || kind == 'kVdN') // This changed between iTunes versions. Uh. Let's support both.
					[playlistArray addObject:[pl get]];
			}
		}
		@catch (NSException *e) { return nil; }
		
		return playlistArray;
}

-(NSArray *)getSelectedTracks {
	if (![self initiTunes])
		return nil;
	
	@try {
		return [[iTunes selection] get];
	}
	@catch (NSException *e) { return nil; }
	
	return nil;
}


-(iTunesPlaylist *)getLibraryPlaylist {
	if (![self initiTunes])
		return nil;
	
	@try {
		return [[[[iTunes sources] objectAtIndex:0] playlists] objectAtIndex:0];
	}
	@catch (NSException *e) { return nil; }
	
	return nil;
}

#pragma mark -
#pragma mark Track stuff

-(NSString *)currentStreamTitle {
	if (![self initiTunes])
		return nil;
	
	@try {
		return [iTunes currentStreamTitle];
	}
	@catch (NSException *e) { return nil; }
}

-(NSArray *)getTracksForPlaylist:(NSString *)thePlaylist {
	//
	// Takes a playlist name as an argument, and returns a regular array with iTunesTrack * pointers.
	//
	NSMutableArray *trackList = [[NSMutableArray alloc] init];

	if (![self initiTunes])
		return nil;
	
	@try {
		SBElementArray *pls = [[[iTunes sources] objectAtIndex:0] playlists];
		
		for (iTunesPlaylist *pl in pls) {
			if ([[pl name] isEqualToString:thePlaylist]) {
				for (iTunesTrack *t in [[pl tracks] get]) {
					[trackList addObject:[t get]];
				}
			}
		}
	}
	@catch (NSException *e) { return nil; }
	
	return trackList;
}

-(NSArray *)getTracksForLibraryPlaylist {
	if (![self initiTunes])
		return nil;
	
	@try {
		// Ugh!
		return [[[[[[iTunes sources] objectAtIndex:0] playlists] objectAtIndex:0] tracks] get];
	}
	@catch (NSException *e) { return nil; }
}

-(iTunesTrack *)getCurrentTrack {
	if (![self initiTunes])
		return nil;
	
	if ([self currentTrackIsStream])
		return nil;
	
	@try {
		iTunesTrack *t = [iTunes currentTrack];
		if (t != nil && [t exists])
			return [t get];
		else
			return nil;
	}
	@catch (NSException *e) { return nil; }
	
	return nil;
}


-(NSString *)getLyricsForTrack:(iTunesTrack *)theTrack {
	if (![self initiTunes]) {
		return nil;
	}
	
	@try {
		NSString *lyrics = [theTrack lyrics];
		if (lyrics && [lyrics length] > 8)
			return lyrics;
		else
			return nil;
	}
	@catch (NSException *e) { return nil; }
	return nil;
}

-(BOOL)setLyrics:(NSString *)theLyrics ForTrack:(iTunesTrack *)theTrack {
	if (theLyrics == nil) return NO;
	if (![self initiTunes]) {
		return NO;
	}
	
	@try {
		[theTrack setLyrics:theLyrics];
	}
	@catch (NSException *e) { return NO; }
	
	return YES;
}

-(NSArray *)getAllTracksForTitle:(NSString *)theTitle byArtist:(NSString *)theArtist {
	if (![self initiTunes])
		return nil;

	NSMutableArray *outArray = [NSMutableArray array];
	
	@try {
		SBElementArray *arr = (SBElementArray *)[[[self getLibraryPlaylist] searchFor:theTitle only:iTunesESrASongs] get];
		// NOTE TO SELF: Don't use [TBUtil string: isEqual...] here, as we DO want diacritics and stuff to matter - but not capitalization
		for (iTunesTrack *track in arr) {
			if ([[track artist] compare:theArtist options:NSCaseInsensitiveSearch] == NSOrderedSame) // Make sure that we don't overwrite some other artist's song
				if ([[track name] compare:theTitle options:NSCaseInsensitiveSearch] == NSOrderedSame) // ... or some other track that matches (a search for Artist - Song might match Artist - Song (live) first!)
				{
					[outArray addObject:[track get]];
				}
		}
	} 
	@catch (NSException *e) { return nil; }
	
	if ([outArray count] == 0)
		return nil;
	else
		return outArray;
}

-(iTunesTrack *)getTrackForTitle:(NSString *)theTitle byArtist:(NSString *)theArtist {
	if (![self initiTunes])
		return nil;
	
	@try {
		SBElementArray *arr = (SBElementArray *)[[self getLibraryPlaylist] searchFor:theTitle only:iTunesESrASongs];
		for (iTunesTrack *track in arr) {
			// Use this to ignore case!
			if ([TBUtil string:[track artist] isEqualToString:theArtist]) // Make sure that we don't overwrite some other artist's song
				if ([TBUtil string:[track name] isEqualToString:theTitle]) // Make sure that we don't overwrite some other song e.g. [this song's name] (live)
				{
					return [track get];
				}
		}
	}
	@catch (NSException *e) { 
        return nil;
    }
	
	return nil;
}

#pragma mark -
#pragma mark Other stuff

-(BOOL)isiTunesRunning {
	if (![self initiTunes]) 
		return NO;
	@try {
		return [iTunes isRunning];
	}
	@catch (NSException *e) { return NO; }
	
	return NO;
}

-(iTunesApplication *)iTunesReference {
	if (iTunes && [iTunes isRunning])
		return iTunes;
	else
		return nil;
}

@end