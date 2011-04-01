//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "MainController.h"
#import "WelcomeScreen.h"

@implementation MainController

//#define DISABLE_CACHE 1
#ifdef DISABLE_CACHE
#warning DISABLE_CACHE ENABLED
#endif

#pragma mark -
#pragma mark Init stuff

@synthesize currentNotification;
@synthesize notificationTimer;

#define kMainWelcomeScreenText \
	@"Welcome to Lyricus!\n" \
	@"To get started, simply play your music in iTunes.\n" \
	@"For a general overview of Lyricus, see the Help menu."

-(void) awakeFromNib {
	//
	// Set up the default settings
	//
	
	[[NSUserDefaults standardUserDefaults] registerDefaults: 
	 [NSDictionary dictionaryWithObjectsAndKeys:
	  [NSNumber numberWithInt:0], 	@"Always on top",			// Off
	  [NSNumber numberWithBool:NO], @"Disable cache warning", // Off
	  [NSNumber numberWithBool:NO], @"Auto-expand playlist view", // Off
	  @"Helvetica",					@"FontName",
	  [NSNumber numberWithFloat:13.0], @"FontSize",
	  [NSArchiver archivedDataWithRootObject:[NSColor whiteColor]], @"BackgroundColor",
	  [NSArchiver archivedDataWithRootObject:[NSColor blackColor]], @"TextColor",
	  [NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:1.0 green:1.0 blue:0.8 alpha:1.0]], @"EditBackgroundColor",
	  
	  nil]];
	
	[lyricView setFont:[NSFont fontWithName:[[NSUserDefaults standardUserDefaults] stringForKey:@"FontName"]
									   size:[[NSUserDefaults standardUserDefaults] floatForKey:@"FontSize"]]];

	[lyricView bind:@"backgroundColor" toObject:[NSUserDefaultsController sharedUserDefaultsController]
 withKeyPath:@"values.BackgroundColor" options:[NSDictionary dictionaryWithObject:NSUnarchiveFromDataTransformerName forKey:NSValueTransformerNameBindingOption]];
	
	[lyricView bind:@"textColor" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.TextColor" options:[NSDictionary dictionaryWithObject:NSUnarchiveFromDataTransformerName forKey:NSValueTransformerNameBindingOption]];
	
	lyricController = [[LyricFetcher alloc] init];
	helper = [iTunesHelper sharediTunesHelper];
	
	[searchWindow setDelegate:self];
	
	[[NSFontManager sharedFontManager] setDelegate:self];
	[[NSFontPanel sharedFontPanel] setDelegate:self];
	[lyricView setUsesFontPanel:YES];
	[lyricView setDelegate:self];
	
	[mainWindow makeFirstResponder:lyricView];
	
	displayedArtist = nil;
	displayedTitle = nil;
	lyricsDisplayed = NO;
	loadingLyrics = NO;
	manualSearch = NO;
	documentEdited = NO;
	receivedFirstNotification = NO;
	
	notificationTimer = nil;
	currentNotification = nil;
	
	
	// Change the lorem ipsum text to something more useful (or at least something less weird)'
	NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	
	[lyricView setString:[NSString stringWithFormat:@"Lyricus v%@ ready. Start playing a track in iTunes to get started!", version]];
	// Restore settings
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Always on top"])
		[mainWindow setLevel:NSFloatingWindowLevel];
	
	// Sign up to receive notifications about the download progress (i.e. which site is being tried)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStatus:) name:@"UpdateStatusNotification" object:nil];
	
	// Remember the window position
	[mainWindow setFrameAutosaveName:@"mainWindow"];	
	
	// Register for iTunes notifications (for when the track changes, etc.)
	[[NSDistributedNotificationCenter defaultCenter]
	 addObserver:self
	 selector:@selector(handleiTunesNotification:)
	 name:@"com.apple.iTunes.playerInfo"
	 object:nil];
	
	// Create a progress indicator
	NSRect spinnerFrame = NSMakeRect([lyricView frame].size.width - 16, 0, 16, 16);
	spinner = [[NSProgressIndicator alloc] initWithFrame:spinnerFrame];
	[spinner setStyle:NSProgressIndicatorSpinningStyle];
	[spinner setControlSize:NSSmallControlSize];
	[spinner setHidden:YES];
	[lyricView addSubview:spinner positioned:NSWindowAbove relativeTo:nil];
	[lyricView setAutoresizesSubviews:YES];
	[spinner setAutoresizingMask:NSViewMinXMargin];
	
	NSButton *zoomButton = [mainWindow standardWindowButton: NSWindowZoomButton];
	[zoomButton setEnabled: YES];
	[zoomButton setTarget: self];
	[zoomButton setAction: @selector(zoomButtonClicked:)];
	
	[self updateTextFieldsFromiTunes];
	[self fetchAndDisplayLyrics:NO];
	
	// Update the site list
	// Is this really needed? [LyricController init] does this already.
	[lyricController updateSiteList];
	// NO CODE goes after this!
}

-(void) userDidCloseWelcomeScreenWithDontShowAgain:(BOOL)state {
	if (state == YES) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"Hide main welcome screen"];
	}
}

-(void)applicationDidFinishLaunching:(NSNotification*)note {
	if ( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"Hide main welcome screen"] ) {
		WelcomeScreen *welcomeScreen = [[WelcomeScreen alloc] initWithText:kMainWelcomeScreenText owningWindow:mainWindow delegate:self];
		[welcomeScreen showWindow:self];
	}
}

-(void) zoomButtonClicked:(id)param {
	NSString *string = [lyricView string];
	if (string == nil || [string length] < 5)
		return;
	
	NSDictionary *stringAttributes = [NSDictionary dictionaryWithObject: [lyricView font] forKey: NSFontAttributeName];
	
	// Step 1: calculate the widest line in the text
	
	NSArray *lines = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];
	
	int width = 0;
	for (NSString *line in lines) {
		NSSize size = [line sizeWithAttributes:stringAttributes];
		
		// This is REALLY ugly, but is needed...
		size.width *= 1.1;
		size.width += 10;
		
		if (size.width > width) {
			width = size.width;
		}
	}
	
	// Step 2: calculate the *height* needed to display the text with a width constrained just enough
	// for the widest line to fit
	NSSize constraints = NSMakeSize(width, MAXFLOAT);
	CGFloat height = [string boundingRectWithSize:constraints options:NSStringDrawingUsesLineFragmentOrigin| NSStringDrawingDisableScreenFontSubstitution attributes:stringAttributes].size.height + 10;
	 
	// Force a minimum size
	if (width < 200)
		width = 200;
	if (height < 300)
		height = 300;

	NSRect rect = [mainWindow frame];
	
	// Don't resize the window so that the resize strip (bottom right) is outside the screen
	CGFloat screenWidth = [[NSScreen mainScreen] frame].size.width;
	if (width > screenWidth)
		width = screenWidth;
	
	// If the window would be displayed partly outside the screen (too much to the right), fix that
	if (width + rect.origin.x >= screenWidth) {
		rect.origin.x = screenWidth - width;
	}

	// Resize the window
	[mainWindow setFrame: NSMakeRect(rect.origin.x, rect.origin.y, width, height) display:NO animate:YES];	
}

#pragma mark -
#pragma mark UI stuff 

-(IBAction)openFontPanel:(id)sender {
	[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:nil];
}

-(IBAction) showPreferencesHelp:(id) sender {
	[TBUtil showAlert:@"Drag and drop to select the order in which the lyric sites will be queried, and enable/disable them using the checkbox next to their name. \nFor some extra hints, "
	 @"hover the mouse pointer over the options and a tooltip should appear (for most options)." withCaption:@"Help"];
}

-(IBAction) showAboutWindow:(id) sender {
	[iconView setImage:[NSApp applicationIconImage]];
	NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	[aboutVersion setStringValue:[@"v" stringByAppendingString:version]];
	
	/* Center the version text */
	[aboutVersion sizeToFit];
	NSRect superFrame = [[aboutVersion superview] frame];
	NSRect versionFrame = [aboutVersion frame];
	versionFrame.origin.x = (superFrame.size.width - versionFrame.size.width) / 2;
	[aboutVersion setFrame:versionFrame];
	
	[aboutWindow makeKeyAndOrderFront:self];
	[aboutTextView setString:
	 @"Everything Lyricus:\n"
	 @"  Thomas Backman <serenity@exscape.org>\n"
	 @"  http://lyricus.exscape.org\n"
	 @"\n"
	 @"Thanks to:\n"
	 @"John Engelhart\n"
	 @"  http://regexkit.sourceforge.net"];
}

-(IBAction)showRegexKitLicense:(id)sender {
	NSString *licenseString = 
	@"Copyright © 2007-2008, John Engelhart\n"
	@"\n"
	 @"All rights reserved.\n"
	 @"\n"
	 @"Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:\n"
	 @"\n"
	 @"* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.\n"
	 @"* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.\n"
	 @"* Neither the name of the Zang Industries nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.\n"
	 @"THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.";
	
	[[NSAlert alertWithMessageText:@"Lyricus uses the RegexKitLite library by John Engelhart." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:licenseString] runModal];
	 
}

-(IBAction) openSearchWindow:(id) sender {
	[NSApp beginSheet:searchWindow modalForWindow:mainWindow modalDelegate:self 
	   didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
	
	[self updateTextFieldsFromiTunes];
}

-(IBAction) openPreferencesWindow:(id) sender {
	[NSApp beginSheet:preferencesWindow modalForWindow:mainWindow modalDelegate:self 
	   didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (sheet == searchWindow)
		[searchWindow orderOut:nil];
	else if (sheet == preferencesWindow) {
		[preferencesWindow orderOut:nil];
	}
}

-(void) setTitle:(NSString *)theTitle {
	[mainWindow setTitle: theTitle];
}

-(IBAction) getFromiTunesButton:(id) sender {
    [self updateTextFieldsFromiTunes];
}

-(void) updateTextFieldsFromiTunes {
    iTunesTrack *track = [helper getCurrentTrack];
	@try {
		if (track != nil && [track artist] != nil && [track name] != nil) {
			// Both or neither!
			[artistField setStringValue: [track artist]];
			[titleField setStringValue: [track name]];
		}
		else {
			NSString *streamTitle = [helper currentStreamTitle];
			if (streamTitle != nil && [streamTitle length] > 5) { // length("a - b" == 5)
				NSArray *tmp = [streamTitle arrayOfDictionariesByMatchingRegex:@"([\\s\\S]+) - ([\\s\\S]+)" withKeysAndCaptures:@"artist", 1, @"title", 2, nil];
				if ([tmp count] != 1)
					return;
				
				NSString *artist = [[tmp objectAtIndex:0] objectForKey:@"artist"];
				NSString *title = [[tmp objectAtIndex:0]  objectForKey:@"title"];
				
				if (artist != nil && title != nil) {
					// Again, both or neither
					[artistField setStringValue:artist];
					[titleField setStringValue:title];
				}
			}
		}
	}
	@catch (NSException *e) {}
}

-(IBAction) alwaysOnTopClicked:(id) sender {
	// The always on top option was checked/unchecked
	// It's boring to restart apps, so let's make it work right away:
	if ([alwaysOnTop state] == NSOnState) {
		[mainWindow setLevel:NSFloatingWindowLevel];	
	}
	else {
		[mainWindow setLevel:NSNormalWindowLevel];
	}
}

-(IBAction) goButton:(id) sender {
    [self fetchAndDisplayLyrics:/*manual=*/YES];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	if (batchDownloader != nil && [batchDownloader batchDownloaderIsWorking]) {
		// The batch downloader is downloading tracks. Ask the user whether we still should quit.
		if ([[NSAlert alertWithMessageText:@"The batch downloader is currently working. Do you still want to quit?" defaultButton:@"Don't quit" alternateButton:@"Quit" otherButton:nil informativeTextWithFormat:@"Lyrics that have been downloaded until now will be saved."] runModal]
			==
			NSAlertDefaultReturn) {
			// Don't quit
			return NSTerminateCancel;
		}
		// else fall through to the checks below...
	}
	
	
	// Make sure unsaved changes are saved by the user
	
	// If there are no unsaved changes, simply quit
	if (![self documentEdited]) {
			return NSTerminateNow;
	}
	
	// There are unsaved changes. Ask the user what to do.
	
	switch ([[NSAlert alertWithMessageText:@"Do you want to save lyric edits before exiting?" defaultButton:@"Save" alternateButton:@"Don't save" otherButton:@"Cancel" informativeTextWithFormat:@"If you don't save now, your changes will be lost. You can cancel to review your changes."] runModal]) {
			
		case NSAlertAlternateReturn:
			// "Don't save"
			return NSTerminateNow;
			break;
			
		case NSAlertDefaultReturn:
			// "Save"
			if ([self saveLyricsToNamedTrack])
				return NSTerminateNow;
			else {
				// Save failed
				if (
				[[NSAlert alertWithMessageText:@"Unable to save lyrics for an unknown reason." defaultButton:@"Abort shutdown" alternateButton:@"Exit without saving" otherButton:nil informativeTextWithFormat:@"Make sure that iTunes is running, then try again. If  you still quit, any changes you have made to the lyric text will be lost."] runModal]
				 ==
					NSAlertAlternateReturn) {
					// "Exit without saving"
					// Save failed but user still wants to exit
					return NSTerminateNow;
				}
				else {
					// "Abort shutdown"
					// Save failed and used din't want to exit
					return NSTerminateCancel;
				}
			}
			break;
		case NSAlertOtherReturn:
			// "Cancel"
			// User wants to cancel the shutdown
			return NSTerminateCancel;
			break;
	}

	// Shouldn't be reached
	return YES;
}

-(BOOL) windowShouldClose:(id)sender {
	if (sender == mainWindow) {
		[NSApp terminate:nil];
		// If the above call returned, the user cancelled the shutdown; let's keep the main window open
		return NO; 
	}
	
	return YES;
}			

-(void) fetchAndDisplayLyrics:(BOOL)manual {
    if (loadingLyrics) {
        return;
	}
	
	if ([[editModeMenuItem title] isEqualToString:@"Leave edit mode"] ) {
		// Edit mode is active
		trackChangedWhileInEditMode = YES;
		// Don't change the displayed lyrics while editing
		return; 
	}

	if ([self documentEdited]) {
		
		switch ([[NSAlert alertWithMessageText:@"The lyrics currently displayed have been modified, but not saved. Do you want to save your changes?" defaultButton:@"Save" alternateButton:@"Don't save" otherButton:@"Cancel" informativeTextWithFormat:@"If you don't save, your changes will be lost."] runModal]) {
				
			case NSAlertAlternateReturn:
				// "Don't save"
				[self setDocumentEdited:NO];
				break;
				
			case NSAlertDefaultReturn:
				// "Save"
				if ([self saveLyricsToNamedTrack]) {
					// We've saved; simply break and let the code below switch to the new track.
					break;
				}
				else {
					// Save failed
					if (
						[[NSAlert alertWithMessageText:@"Unable to save lyrics. Do you want to switch the lyric display anyway? Your changes will be lost." defaultButton:@"Don't switch" alternateButton:@"Switch and discard changes" otherButton:nil informativeTextWithFormat:@"If  you still switch the lyric display, any changes you have made to the lyric will be lost."] runModal]
						==
						NSAlertAlternateReturn) {
						// Simply break and let the code below switch to the new track.
						break;
					}
					else {
						// "Abort shutdown"
						// Save failed and used din't want to exit
						return;
					}
				}
				break;
			case NSAlertOtherReturn:
				// "Cancel"
				// User wants to cancel the track switch
				return;
		}
	}
	
    manualSearch = manual;
	
	NSString *artist, *title;
	artist = [artistField stringValue];
	title  = [titleField stringValue];
	
	if ([artist length] == 0 || [title length] == 0) {
		if (manualSearch == YES) { // Don't show if it was called programmatically
			[[NSAlert alertWithMessageText:@"No artist/title pair specificed" defaultButton:@"OK" alternateButton:nil otherButton:nil
				 informativeTextWithFormat:@"You need to type in both an artist and a track title to search."] runModal];
		}
		return;
	}
	[self disableEditMode];
	[goButton setEnabled:NO];
	[spinner setHidden:NO];
	[spinner setUsesThreadedAnimation:YES];
	[spinner startAnimation:nil];
	
	[NSApp endSheet:searchWindow];
	loadingLyrics = YES;
	// Display loading messages in Helvetica 13
	
	[lyricView setFont:[NSFont fontWithName:@"Helvetica" size:13.0]];

	[lyricView setString:@"Loading lyrics, please wait...\n"];
	[mainWindow setTitle:@"Lyricus - loading..."];
	
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:title, @"title", artist, @"artist", nil];
	NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(runThread:) object:data];
	[thread start];
}

- (void)runThread:(NSDictionary *)data {
	NSString *title = [data objectForKey:@"title"];
	NSString *artist = [data objectForKey:@"artist"];

	if (title == nil || artist == nil) {
		loadingLyrics = NO;
	}
	
	NSString *lyricStr;

	// This is done in a superclass in the lyric classes, so we need to duplicate the code for this one instance
	[[NSNotificationCenter defaultCenter] postNotificationName:@"UpdateStatusNotification" object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:LyricusNoteHeader], @"type", @"Trying iTunes...", @"Text", nil]];
	
    NSError *err = nil;
    
    // First, lets check if iTunes has an entry for this track already
	iTunesTrack *currentTrack = [helper getTrackForTitle:title byArtist:artist];
	NSString *iTunesLyrics = [helper getLyricsForTrack:currentTrack];
#ifndef DISABLE_CACHE
	if (iTunesLyrics != nil && [iTunesLyrics length] > 5) {
		lyricStr = iTunesLyrics;
	}
	else 
#endif 
	{
		// Not in iTunes, lets fetch it
		lyricStr = [lyricController fetchLyricsForTrack:title byArtist:artist error:&err];
		
		// Beautiful code:
		// (Basically, it checks if the data we got is OK, ond if it should save it to iTunes)
		if (lyricStr != nil) {
			if ([[currentTrack artist] isEqualToString:artist] && [[currentTrack name] isEqualToString:title]) {
				// The above line is to make sure we don't save into the wrong track, in case the currently displayed track isn't the one playing
				
				// This needs to be done when the track isn't playing. Otherwise, there will be a (very) noticable pause in the playback when iTunes writes the data to disk.
				NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
									  currentTrack, @"currentTrack",
									  [NSString stringWithString:lyricStr], @"lyric",
									  nil];
				
				NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(updateLyriciniTunes:) object:data];
				[thread start];
			}
		}
	}
	
	if (lyricStr == nil) {
        if (err == nil) {
            lyricStr = [NSString stringWithFormat:@"No lyrics found for:\n%@ - %@",
                        artist, title];
        }
        else { // error
            lyricStr = [NSString stringWithFormat: @"An error occured:\n%@", [err localizedDescription]];
        }
		[self performSelectorOnMainThread:@selector(setTitle:) withObject:@"Lyricus" waitUntilDone:YES];
		lyricsDisplayed = NO;
	}
	else if (lyricStr != nil) {
		// We found some lyrics!
		NSString *fullTitle = [NSString stringWithFormat:@"%@ - %@", artist, title];
		[self performSelectorOnMainThread:@selector(setTitle:) withObject:fullTitle waitUntilDone:YES];
		lyricsDisplayed = YES;
	}
	
	// Display lyrics + set font
	[lyricView setFont:[NSFont fontWithName:[[NSUserDefaults standardUserDefaults] stringForKey:@"FontName"]
									   size:[[NSUserDefaults standardUserDefaults] floatForKey:@"FontSize"]]];

	[lyricView performSelectorOnMainThread:@selector(setString:) withObject:lyricStr waitUntilDone:YES];

	displayedArtist = [artist copy];
	displayedTitle = [title copy];
	
	loadingLyrics = NO;
    
	[spinner stopAnimation:nil];
	[spinner setHidden:YES];
	[goButton setEnabled:YES];

	
	// If the track changed while loading, go get the NEW lyrics instead. Do NOT do this with manual searches, or the current track
	// would be displayed no matter what.
	
	if (!manualSearch) {
		NSString *currentArtist;
		NSString *currentTitle;
		if ([helper currentTrackIsStream]) {
			NSString *streamTitle = [helper currentStreamTitle];
			if (streamTitle != nil && [streamTitle length] > 5) { // length("a - b" == 5)
				NSArray *tmp = [streamTitle arrayOfDictionariesByMatchingRegex:@"([\\s\\S]+) - ([\\s\\S]+)" withKeysAndCaptures:@"artist", 1, @"title", 2, nil];
				if ([tmp count] != 1)
					return;
				
				currentArtist = [[tmp objectAtIndex:0] objectForKey:@"artist"];
				currentTitle = [[tmp objectAtIndex:0]  objectForKey:@"title"];
			}
			else {
				currentArtist = @"";
				currentTitle = @"";
			}
		}
		else {
			currentArtist = [[helper getCurrentTrack] artist];
			currentTitle = [[helper getCurrentTrack] name];							
		}

		// Check whether the track has changed or not
		if ( ! ([displayedArtist isEqualToString:currentArtist] && [displayedTitle isEqualToString:currentTitle]) ) {
				[self updateTextFieldsFromiTunes];
				[self fetchAndDisplayLyrics:NO];
		}
	}
}	

- (IBAction) closeSearchWindow:(id) sender {
	[NSApp endSheet:searchWindow];
}

- (IBAction) closePreferencesButton:(id) sender {

	[lyricController updateSiteList];
	if ([[lyricController sitesByPriority] count] == 0) {
		// Make sure the user selects at least one site
		[TBUtil showAlert:@"Please enable at least one of the sites in the list." withCaption:@"You have not enabled any sites."];
		return;
	}
	
	[[NSColorPanel sharedColorPanel] close];
	[NSApp endSheet:preferencesWindow];
}

-(void)doReplace:(NSDictionary *)dict {
	//
	// Ugly hack. Used to make the image replacement on the main thread.
	//
	
	NSImage *image = [NSImage imageNamed:[dict objectForKey:@"imageName"]];
	NSTextAttachmentCell *attachmentCell = [[NSTextAttachmentCell alloc] initImageCell:image];
	NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
	[attachment setAttachmentCell:attachmentCell];
	NSAttributedString *attributedString = [NSAttributedString attributedStringWithAttachment:attachment];
	
	int position = [[dict objectForKey:@"position"] intValue];
	[[lyricView textStorage] replaceCharactersInRange:NSMakeRange([[lyricView textStorage] length] - position - 1, 1) withAttributedString:attributedString];
}

-(void) updateStatus:(NSNotification *)note {
	//
	// Called when we receive a notification about the download progress.
	// The check whether to send or not is on the *sending* side, so if we get here, just display them.
	//
	
	//return;
	
	NSDictionary *info = [note userInfo];
	if (info == nil)
		return;
	NSString *text = [info objectForKey:@"Text"];
	int type = [[info objectForKey:@"type"] intValue];
	
	text = [text stringByAppendingString:@"\n"];

	if (type == LyricusNoteHeader) {
		[lyricView performSelectorOnMainThread:@selector(appendString:) withObject:text waitUntilDone:YES];
	}
	else if (type == LyricusNoteStartedWorking) {
		[lyricView performSelectorOnMainThread:@selector(appendString:) withObject:@"\t" waitUntilDone:YES];
		[lyricView performSelectorOnMainThread:@selector(appendImageNamed:) withObject:@"icon_working.png" waitUntilDone:YES];
		[lyricView performSelectorOnMainThread:@selector(appendString:) withObject:@" " waitUntilDone:YES];
		[lyricView performSelectorOnMainThread:@selector(appendString:) withObject:text waitUntilDone:YES];
	}
	else if (type == LyricusNoteSuccess) {
		NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:[text length]+ 1], @"position", @"icon_found.png", @"imageName", nil];
		[self performSelectorOnMainThread:@selector(doReplace:) withObject:data waitUntilDone:YES];
	}
	else if (type == LyricusNoteFailure) {
		NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:[text length] + 1], @"position", @"icon_notfound.png", @"imageName", nil];
		[self performSelectorOnMainThread:@selector(doReplace:) withObject:data waitUntilDone:YES];
	}
}

#pragma mark -
#pragma mark Util/misc stuff 

-(BOOL) track:(iTunesTrack *) theTrack isEqualToTrack:(iTunesTrack *)otherTrack {
	@try {
	if (theTrack == otherTrack)
		return YES;
	if (theTrack != nil && [theTrack exists] && otherTrack != nil && [otherTrack exists]) {
		if (
			[[theTrack artist] isEqualToString:[otherTrack artist]] &&
			[[theTrack name] isEqualToString:[otherTrack name]]
			) { return YES; }
		else return NO;
	}
	else
		return NO;
	}
	@catch (NSException *e) { return NO; }
	
	return NO;
}

-(void) updateLyriciniTunes:(NSDictionary *)data {
	iTunesApplication *iTunes = [helper iTunesReference];
	if (iTunes == nil)
		return;
	
	iTunesTrack *theTrack = [data objectForKey:@"currentTrack"];
	NSString *theLyric = [data objectForKey:@"lyric"];
	
	@try {
		if (theTrack == nil || ![theTrack exists] || theLyric == nil)
			return;
	}
	@catch (NSException *e) { return; }
	
	iTunesTrack *nextTrack;
	@try {
		while (1) {
			// Wait until track stops playing, to avoid the skip when iTunes writes the lyrics to disk
			if (iTunes == nil || ![iTunes isRunning]) {
				NSLog(@"iTunes not running anymore, can't save data");
				break;
			}
			
			@try {
				nextTrack = [iTunes currentTrack];
				if (![self track:nextTrack isEqualToTrack:theTrack] && [iTunes playerState] == iTunesEPlSPlaying ) {
					[helper setLyrics:theLyric ForTrack:theTrack];
					break;
				}
			}
			@catch (NSException *e) { return; }
			@finally  { 
				sleep(10); // There's no rush! It'll work even if it's a bit late.
			}
		}
	}
	@catch (NSException *e) { NSLog(@"Unable to save lyrics to iTunes: some exception occured."); }
}

-(BOOL) haveLyricsLocallyForCurrentTrack {
	//
	// Returns YES if lyric is in iTunes, NO otherwise
	//
	iTunesTrack *currentTrack = [helper getCurrentTrack];
	if (currentTrack == nil)
		return NO;
	
	return ([helper getLyricsForTrack:[helper getCurrentTrack]] != nil);
}

-(void)trackUpdated {
	//
    // This is called whenever iTunes starts playing a track. We need to check whether if it's a new track or not.
	//
	
	// Reset notification handling
	receivedFirstNotification = NO;
	
	NSString *newTrack;
	if (![helper currentTrackIsStream])
		newTrack = [NSString stringWithFormat:@"%@ - %@", [[currentNotification userInfo] objectForKey:@"Artist"], [[currentNotification userInfo] objectForKey:@"Name"]];
	else
		newTrack = [helper currentStreamTitle];

	if (!lastTrack || ![newTrack isEqualToString:lastTrack]) {
			// Track DID change,so lets get the lyrics and stuff.
			lastTrack = [NSString stringWithString:newTrack];
			[self updateTextFieldsFromiTunes];
			[self fetchAndDisplayLyrics:NO];
	}
}

-(void)handleiTunesNotification:(NSNotification *)note {
	//
	// Receives notifications from iTunes, and forwards them to trackUpdated: if a track started playing
	//
	
	NSString *location = [[note userInfo] objectForKey:@"Location"];
	if (location == nil)
		return;
	
	BOOL isStream = ([[note userInfo] objectForKey:@"Stream Title"] != nil);
	
	if ([[location substringToIndex:4] isEqualToString:@"file"] || isStream) {
		if ([[[note userInfo] objectForKey:@"Player State"] isEqualToString:@"Playing"]) {
			if (!isStream) {
				self.currentNotification = note;
				[self trackUpdated];
			}
			else {
				// Wait for the FIRST of two conditions to occur:
				// a) We receive another notification and uses that
				// b) Two seconds pass without another notification
				// The reason for this is simple (but annoying): there are no specific artist/title tags when the metadata
				// comes from a stream - only a stream title, which often LOOKS like a title to a program, yet is useless.
				// The real "artist - title" string usually arrives in a SECOND notification a second or two later.

				if (!receivedFirstNotification) {
					// This is the first notification - let's wait and see
					receivedFirstNotification = YES;
					self.currentNotification = note;

					NSThread* timerThread = [[NSThread alloc] initWithTarget:self selector:@selector(startTimerThread) object:nil];
					[timerThread start]; //start the thread
				}
				else {
					// Yay, we received the second notification
					self.currentNotification = note;
					if (notificationTimer != nil) {
						[notificationTimer invalidate];
					}
					notificationTimer = nil;
					[self trackUpdated];
				}
			}
		}
	}
}

-(void) startTimerThread {
	NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
	notificationTimer = [NSTimer scheduledTimerWithTimeInterval: 2.0 target: self selector: @selector(trackUpdated) userInfo: nil repeats: NO];
	
	[runLoop run];	
}

#pragma mark -
#pragma mark Misc.

-(void)disableEditMode {
	[editModeMenuItem setTitle:@"Enter edit mode"];
	[lyricView setEditable:NO];
	[mainWindow setTitle:[NSString stringWithFormat:@"%@ - %@", displayedArtist, displayedTitle, nil]];
	[lyricView setBackgroundColor:(NSColor *)[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] valueForKey:@"BackgroundColor"]]];
	
	if (trackChangedWhileInEditMode) {
		trackChangedWhileInEditMode = NO;
		[self fetchAndDisplayLyrics:NO];
	}
}
	
-(IBAction)toggleEditMode:(id) sender {
	if (!displayedArtist || !displayedTitle)
		return;
	
	if ([[editModeMenuItem title] isEqualToString:@"Leave edit mode"]) {
		[self disableEditMode];
	}
	else {
		// Enable edit mode
		
		if ([helper getTrackForTitle:displayedTitle byArtist:displayedArtist] == nil) {
			[TBUtil showAlert:@"You're trying to edit the lyrics to a track I can't find in your iTunes library!" withCaption:@"Track not found in iTunes"];
			return;
		}
		
		if (lyricsDisplayed == NO) {
			// We're trying to ADD lyrics to a track that doesn't have them: remove the "nothing found" text
			// from the window:
			[lyricView setString:@""];
		}

		[editModeMenuItem setTitle:@"Leave edit mode"];
		[lyricView setEditable:YES];		

		[lyricView setBackgroundColor: (NSColor *)[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"EditBackgroundColor"]]];
		
		[mainWindow setTitle:[NSString stringWithFormat:@"EDITING: %@ - %@", displayedArtist, displayedTitle, nil]];		
	}
}

-(IBAction)saveLyrics:(id) sender {
	[self saveLyricsToNamedTrack];
}

-(BOOL)saveLyricsToNamedTrack {
	BOOL ret = FALSE; // What we return
	if (!displayedArtist || !displayedTitle) {
		[TBUtil showAlert:@"Try searching for the track again." withCaption:@"Lyricus is unable to save the lyrics because the artist and/or title is not known."];
		ret = FALSE;
		goto end_return;
	}
	
	NSArray *theTracks = [helper getAllTracksForTitle:displayedTitle byArtist:displayedArtist];
	if (theTracks == nil) {
		[TBUtil showAlert:@"The currently displayed track is not in your iTunes library. Lyricus saves its lyrics in the audio file metadata and as such cannot save." withCaption:@"Unable to save lyrics"];
		ret = FALSE;
		goto end_return;
	}
	else
		ret = TRUE;
	
	// Ugh, setLyrics returns void, so we can't check for errors.
	// We'll have to assume it worked if the track was found above.
	NSString *newLyric = [lyricView string];
	
	for (iTunesTrack *theTrack in theTracks) {
		[theTrack setLyrics:newLyric];
	}
	
	// This line must be fixed BEFORE disabling edit mode, to not ask the user if the changes are already saved
	// It must also be BEFORE end_return below, so that a failure to save doesn't
	// set documentEdited to NO.
	[self setDocumentEdited:NO];
	
end_return:
	lyricsDisplayed = YES; // To make sure edit mode isn't bugged when adding new lyrics to a track
	[self disableEditMode];

	return ret;
}

-(IBAction)saveDisplayedLyricsToCurrentlyPlayingTrack:(id) sender  {
	NSString *newLyric = [lyricView string];

	if (newLyric == nil)
		newLyric = @"";
	
	[[helper getCurrentTrack] setLyrics: newLyric];
	
	[self disableEditMode];
	
	// Refresh the lyric display and fix the title, etc.
	[self setDocumentEdited:NO];
	
	return;
}

-(IBAction)openSongMeaningsPage:(id)sender {
	if (!displayedArtist || !displayedTitle) {
		[TBUtil showAlert:@"Starting playing a track in iTunes, or do a manual search, then try again." withCaption:@"Unable to open songmeanings page because no song is currently displayed."];
		return;
	}
	[spinner setHidden:NO];
	[spinner startAnimation:nil];
		
	// This is done in a separate thread to not stall the UI while the network is loading
	NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(openSongmeaningsThread:) object:nil];
	[thread start];
}

-(void)openSongmeaningsThread:(NSArray *)data {
	if (!songmeanings) {
		songmeanings = [[TBSongmeanings alloc] init];
	}
    NSError *err = nil;
	
	NSString *artistURL = [songmeanings getURLForArtist:displayedArtist error:&err];
	if (!artistURL && err == nil) {
		// There really is nothing more to say there as an informative text.
		[TBUtil showAlert:@"" withCaption:@"Lyricus is unable to open this track's songmeanings page because the artist is not in the database."];
		goto end_func;
	}
    else if (!artistURL && err != nil) {
        [TBUtil showAlert:@"Make sure that you are connected to the internet." withCaption:@"Lyricus was unable to open this track's songmeanings page due to an error."];
		goto end_func;
    }
	
	NSString *myTitle = displayedTitle;
	
	if ([displayedTitle containsString:@"(live" ignoringCaseAndDiacritics:YES]) {
		myTitle = [NSString stringWithString:[displayedTitle stringByReplacingOccurrencesOfRegex:@"(?i)(.*?)\\s*\\(live.*" withString:@"$1"]];
	}
	
	NSString *lyricURL = [songmeanings getLyricURLForTrack:myTitle fromArtistURL:artistURL error:&err];
	if (!lyricURL && err == nil) {
		// Same thing here, I can't think of a useful "informative text" for this message. There's just nothing to do.
		[TBUtil showAlert:@"" withCaption:@"Lyricus is unable to open this track's songmeanings page because the track is not in the database."];
		goto end_func;
	}
    else if (!lyricURL && err != nil) {
        [TBUtil showAlert:@"Make sure that you are connected to the internet." withCaption:@"Lyricus was unable to open this track's songmeanings page due to an error."];
        goto end_func;

    }
	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:lyricURL]];
end_func:
	[spinner stopAnimation:nil];
	[spinner setHidden:YES];
	return;
}

-(void) textDidChange:(NSNotification *)notification {
	[self setDocumentEdited: YES];
}

-(IBAction)lyricSearchUpdateIndex:(id) sender {
    [self openLyricSearch:sender];
    [lyricSearch updateTrackIndex:sender];
}

-(IBAction)openBatchDownloader:(id)sender {
    if (batchDownloader == nil) {
        batchDownloader = [[Batch alloc] initWithWindowNibName:@"Batch"];
    }
	
	while (![helper isiTunesRunning]) {
		if ([[NSAlert alertWithMessageText:@"The batch downloader needs iTunes open to work, and iTunes doesn't appear to be open." defaultButton:@"Check again" alternateButton:@"Abort" otherButton:nil informativeTextWithFormat:@"Start iTunes and click \"check again\". If you don't want to open the batch downloader now, click \"abort\"."] runModal]
			==
			NSAlertDefaultReturn) {
			// User clicked retry, so restart the loop and check for iTunes again
			continue;
		}
		else {
			// User clicked abort; don't show the batch downloader
			return;
		}
	}
	
	// This point is only reached if iTunes is running.

	[batchDownloader showBatchDownloader];
}

-(IBAction)openLyricSearch:(id)sender {
    if (lyricSearch == nil) {
        lyricSearch = [[LyricSearchController alloc] initWithWindowNibName:@"LyricSearch"];
    }
    [lyricSearch showWindow:self];
    [lyricSearch.window makeKeyAndOrderFront:self];
    [lyricSearch showLyricSearch:self];
}

-(BOOL) documentEdited {
	return documentEdited;
}

-(void) setDocumentEdited:(BOOL) value {
	documentEdited = value;
	[mainWindow setDocumentEdited:value];
}

@end