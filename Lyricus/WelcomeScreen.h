//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Foundation/Foundation.h>


@interface WelcomeScreen : NSWindowController {
	IBOutlet NSButton *dontShowAgain;
	IBOutlet NSButton *closeButton;
	IBOutlet NSTextField *textLabel;
	
	NSString *text;
	id delegate;
	NSWindow *owner;
}

-(id)initWithText:(NSString *)inText owningWindow:(NSWindow *)inOwner delegate:(id)inDelegate;

@end

//
// Informal protocol for the delegate
//

@interface NSObject (WelcomeScreen)
-(void)userDidCloseWelcomeScreenWithDontShowAgain:(BOOL)state;
@end