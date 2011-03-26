//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "LyricFetcher.h"
#import "RegexKitLite.h"

@implementation LyricFetcher

static LyricFetcher *sharedLyricFetcher = nil;

+(LyricFetcher *)sharedLyricFetcher {
    @synchronized(self) {
        if (sharedLyricFetcher == nil) {
            sharedLyricFetcher = [[LyricFetcher alloc] init];
        }
    }
    return sharedLyricFetcher;
}

+(id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedLyricFetcher == nil) {
            sharedLyricFetcher = [super allocWithZone:zone];
            return sharedLyricFetcher;
        }
    }
    return sharedLyricFetcher;
}

- (id)copyWithZone:(NSZone *)zone { 
	return self; 
} 

-(LyricFetcher *)init {
    self = [super init];
	if (self) {
		[self updateSiteList];
	}
	
	return self;
}

#pragma mark -
#pragma mark Public

@synthesize sitesByPriority;

-(NSString *)fetchLyricsForTrack:(NSString *)theTrack byArtist:(NSString *)theArtist error:(NSError **)error {
	
	if (theTrack && [theTrack containsString:@"(live" ignoringCaseAndDiacritics:YES]) {
        theTrack = [theTrack stringByReplacingOccurrencesOfRegex:@"(?i)(.*?)\\s*\\(live.*" withString:@"$1"];
	}
	
	// This should never happen, as there are checks to prevent from saving an empty list. Still...
	if (sitesByPriority == nil || [sitesByPriority count] == 0) {
		[[NSAlert alertWithMessageText:@"Unable to fetch lyrics because the site list isn't set up." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"To fix this, please go to the preferences window and enable at least one site."] runModal];
		return nil;
	}
	
	// Runs through the list of sites, in order, until
	// 1) there are no more sites (return nil), or
	// 2) the lyric is found and returned
    
    NSString *lyrics = nil;

	for (id site in sitesByPriority) {
		lyrics = [site fetchLyricsForTrack:theTrack byArtist:theArtist error:error];
		if (lyrics != nil)
			return lyrics;
    }
	
	return nil;
}

-(void) updateSiteList {
	//
	// Update the list of sites to use, i.e. the array that is used for lookups later
	//
	
	// The instance variable used later
	sitesByPriority = [[NSMutableArray alloc] init];
	
	// This one is only used here; it's grabbed straight from the settings in the preferences window
	NSArray *prio = [[NSUserDefaults standardUserDefaults] objectForKey:@"Site priority list"];
	if (!prio) {
		// Give it another shot before complaining to the user
		[[SitePriorities alloc] init];
		prio = [[NSUserDefaults standardUserDefaults] objectForKey:@"Site priority list"];
	}
	
	if (!prio) {
		[TBUtil showAlert:@"Please go into the preferences window, drag the sites in the order you'd like, then try again. Make sure to enable at least one site."
			  withCaption:@"Site priority list not found!"];
		return;
	}
	
	// This for loop sets it all up, highest priority first of course.
	// A bit ugly, but it's good enough for now.
	for (NSDictionary *site in prio) {
		int enabled = [[site objectForKey:@"enabled"] intValue];
		if (!enabled) {
			// Ignore sites that aren't checked as enabled in the preferences window
			continue;
		}
		
		NSString *siteName = [[site objectForKey:@"site"] lowercaseString];
		
		if ([siteName isEqualToString:@"darklyrics"])
			[sitesByPriority addObject: [[TBDarklyrics alloc] init]];
		else if ([siteName isEqualToString:@"songmeanings"])
			[sitesByPriority addObject: [[TBSongmeanings alloc] init]];
        else if ([siteName isEqualToString:@"azlyrics"])
            [sitesByPriority addObject: [[TBAZLyrics alloc] init]];
	}
}

@end
