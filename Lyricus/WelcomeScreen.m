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
		
		NSRect textFrame = [text boundingRectWithSize:NSMakeSize([[owner contentView] frame].size.width, (unsigned int)-1) 
											  options:(NSStringDrawingUsesDeviceMetrics | NSStringDrawingUsesLineFragmentOrigin )
										   attributes:stringAttributes];
		NSRect windowFrame = [self.window frame];

		// Set the label's origin coordinates as measured in Xcode
		textFrame.origin.x = 20;
		textFrame.origin.y = 57;

		// Calculate the window height (textLabel + padding above + padding below + some magic value)

		NSRect ownerFrame = [owner frame];
		NSRect screenFrame = [[NSScreen mainScreen] frame];

		// Center the window on the owner window
		windowFrame.origin.x = (ownerFrame.origin.x + (ownerFrame.size.width / 2)) - (windowFrame.size.width / 2);
		windowFrame.origin.y = (ownerFrame.origin.y + (ownerFrame.size.height / 2)) - (windowFrame.size.height / 2);
		
		// If the above position has part of the window off screen, move it back.
		if (windowFrame.origin.x + windowFrame.size.width > screenFrame.size.width)
			windowFrame.origin.x = screenFrame.size.width - windowFrame.size.width;
		if (windowFrame.origin.y + windowFrame.size.height > screenFrame.size.height)
			windowFrame.origin.y = screenFrame.size.height - windowFrame.size.height;

		// These need to be set in the correct order, or the textLabel will be positioned incorrectly
		[self.window setFrame:windowFrame display:NO animate:NO];		
		[textLabel setFrame:textFrame];
	}
	
	[self showWindow:self];
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
