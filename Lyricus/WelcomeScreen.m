//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "WelcomeScreen.h"

@implementation WelcomeScreen

-(id)init {
	return nil;
}

-(id)initWithWindowNibName:(NSString *)windowNibName {
	self = [super initWithWindowNibName:windowNibName];
	if (self) {
		text = nil;
		delegate = nil;
		owner = nil;
	}
	return self;
}

-(id)initWithText:(NSString *)inText owningWindow:(NSWindow *)inOwner delegate:(id)inDelegate {
	self = [self initWithWindowNibName:@"WelcomeScreen"];
	if (self) {
		text = [inText copy];
		owner = inOwner;
		delegate = inDelegate;
	}
	return self;
}

-(void)awakeFromNib {
	// Both init and show are called before awakeFromNib. Not pretty.
	[textLabel setStringValue:text];
	
	if (owner != nil) {
		NSDictionary *stringAttributes = [NSDictionary dictionaryWithObject: [textLabel font] forKey: NSFontAttributeName];
		
		NSRect textFrame = [text boundingRectWithSize:NSMakeSize(textLabel.frame.size.width, (unsigned int)-1) 
											  options:(NSStringDrawingDisableScreenFontSubstitution | NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading )
										   attributes:stringAttributes];
		NSRect windowFrame = [self.window frame];

		// Set the label's origin coordinates as measured in Xcode
		textFrame.origin.x = 20;
		textFrame.origin.y = 57;
		
		// FIXME: Ugh! WHY is this needed to not clip?!
		textFrame.size.width += 5;
		
		// Calculate the window height (textLabel + padding above + padding below + some magic value)
		windowFrame.size.height = textFrame.size.height + 20 + 65 + 10;

		// Center the window on the owner window
		NSRect ownerFrame = [owner frame];
		windowFrame.origin.x = (ownerFrame.origin.x + (ownerFrame.size.width / 2)) - (windowFrame.size.width / 2);
		windowFrame.origin.y = (ownerFrame.origin.y + (ownerFrame.size.height / 2)) - (windowFrame.size.height / 2);
		
		// If the above position has part of the window off screen, move it back.
		NSRect screenFrame = [[NSScreen mainScreen] frame];
		if (windowFrame.origin.x + windowFrame.size.width > screenFrame.size.width)
			windowFrame.origin.x = screenFrame.size.width - windowFrame.size.width;
		if (windowFrame.origin.y < 0)
			windowFrame.origin.y = 0;

		[self setShouldCascadeWindows:NO];
		// These need to be set in the correct order, or the textLabel will be positioned incorrectly
		[self.window setFrame:windowFrame display:NO animate:NO];		
		[textLabel setFrame:textFrame];
		//		[textLabel setDrawsBackground:YES];
		//		[textLabel setBackgroundColor:[NSColor yellowColor]];
	}
}

-(void)showWindow:(id)sender {
	[super showWindow:sender];
	[self.window makeKeyAndOrderFront:sender];
}

-(IBAction)closeButtonClicked:(id)sender {
	if ([delegate respondsToSelector:@selector(userDidCloseWelcomeScreenWithDontShowAgain:)]) {
		[delegate userDidCloseWelcomeScreenWithDontShowAgain:(BOOL)[dontShowAgain state]];
	}
	
	[self.window close];
}

- (void)dealloc{
    [super dealloc];
}

@end
