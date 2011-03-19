
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "SitePriorities.h"
#define kType @"exscapeLyricType"

@implementation SitePriorities

#pragma mark -
#pragma mark Init stuff + save

-(void)awakeFromNib {
	// Set up to allow drag and drop, using a type that nobody else is likely to use, ever
	[table registerForDraggedTypes:[NSArray arrayWithObject:kType]];
}

-(BOOL)load {
	data = [[NSUserDefaults standardUserDefaults] objectForKey:@"Site priority list"];

	// Delete LyricWiki entry if present
	// Old-style C loop due to some trouble with the foreach variety
	// Yes, this is ugly. Don't code when you should sleep, kids.
	if (data != nil) {
		int del = -1;
		int i = 0;
		for (i=0; i < [data count]; i++) {
			NSDictionary *dict = [data objectAtIndex:i];
			if ([[dict objectForKey:@"site"] isEqualToString:@"Lyricwiki"]) {
				del = i;
				break;
			}
		}
		
		if (del != -1) {
			[data removeObjectAtIndex:i];
		}
	}
	
	return (data != nil);
}

-(BOOL)save {	
	[[NSUserDefaults standardUserDefaults] setObject:data forKey:@"Site priority list"];
	return YES;
}

-(id) init
{
    self = [super init];
	if (!self) 
		return nil;
	
	//
	// Very ugly, but it's still the easiest way to do this.
	//
	
	[self load];
	if (!data) { // if load failed
		data = [[NSMutableArray alloc] init];
		
		NSMutableDictionary *d; 

		d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt:1], @"enabled",
			 @"Songmeanings", @"site",
			 nil];
		[data addObject:d];
		
		d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt:0], @"enabled",
			 @"Darklyrics", @"site",
			 nil];
		[data addObject:d];
		
		[self save];
	}
	
    [table setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
	return self;
}

#pragma mark -
#pragma mark Tableview stuff

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard {
	// User is dragging, copy the row numbers of the rows to the pasteboard
	
    NSData *theData = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObject:kType] owner:self];
    [pboard setData:theData forType:kType];
	
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row 
	proposedDropOperation:(NSTableViewDropOperation)op 
{
	// To be honest I'm not sure how this works...! But it does work, good enough!
	if (op == NSTableViewDropOn) {
        [tv setDropRow:(row+1) dropOperation:NSTableViewDropAbove];
    }
	return NSDragOperationGeneric;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)newRow dropOperation:(NSTableViewDropOperation)operation 
{
	//
	// There's a certain amount of black magic surrounding this method as well...
	//
	
	// If the new row is at the bottom, we need to do this to not get an
	// out of bounds error.
	if (newRow == [data count])
		newRow--;
	
    NSPasteboard* pboard = [info draggingPasteboard];
    NSData* rowData = [pboard dataForType:kType];
    NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
	
	// Since only a single row can be accepted, we need not worry about the other ones - there'll never be any.
    int dragRow = [rowIndexes firstIndex];
	
	// Remove the old row and insert it at the new position
	id old = [data objectAtIndex:dragRow];
	[data removeObject:old];
	[data insertObject:old atIndex:newRow];
	
	// Reload data and save site priority list
	[table reloadData];
	return [self save];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	// Kind of speaks for itself. Not sure the if() is needed, but better safe than sorry.
	if (data)
		return [data count];
	else 
		return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	// Get the data for row 'rowIndex' at column 'aTableColumn'
	NSMutableDictionary *e = [data objectAtIndex:rowIndex];
	return [e valueForKey:[aTableColumn identifier]];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	// Set the data for row 'rowIndex' at column 'aTableColumn'...
	NSMutableDictionary *e = [data objectAtIndex:rowIndex];
	[e setValue:anObject forKey:[aTableColumn identifier]];
	
	// ... and save the changes to the defaults system
	[self save];
}

@end
