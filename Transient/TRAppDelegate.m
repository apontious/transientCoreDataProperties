//
//  TRAppDelegate.m
//  Transient Core Data Properties http://github.com/apontious/transientCoreDataProperties
//
//  Created by Andrew Pontious on 6/16/12.
//  Copyright (c) 2012 Andrew Pontious.
//  Some right reserved: http://opensource.org/licenses/mit-license.php
//

#import "TRAppDelegate.h"

@interface TRAppDelegate () <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, weak) IBOutlet NSButton *addNameButton;
@property (nonatomic, weak) IBOutlet NSTextField *textField;
@property (nonatomic, weak) IBOutlet NSTableView *tableView;

@property (nonatomic, weak) IBOutlet NSWindow *window;

@property (readonly, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (nonatomic, copy) NSArray<NSManagedObject *> *forgettables;

@end

@implementation TRAppDelegate

@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize managedObjectContext = __managedObjectContext;

// apontious 6/16/2012: Must use this access point, instead of applicationDidFinishLaunching:, if we want to do things before e.g. table view is populated.
- (void)awakeFromNib {
    [self refresh:nil];
}

// Creates if necessary and returns the managed object model for the application.
- (NSManagedObjectModel *)managedObjectModel {
    if (__managedObjectModel) {
        return __managedObjectModel;
    }
	
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Transient" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

// Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (__persistentStoreCoordinator != nil) {
        return __persistentStoreCoordinator;
    }
    
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (mom == nil) {
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }

    NSError *error;

    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![coordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    __persistentStoreCoordinator = coordinator;
    
    return __persistentStoreCoordinator;
}

// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) 
- (NSManagedObjectContext *)managedObjectContext {
    if (__managedObjectContext != nil) {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator == nil) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    __managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [__managedObjectContext setPersistentStoreCoordinator:coordinator];

    return __managedObjectContext;
}

// Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}

#pragma mark Actions

- (IBAction)addName:(id)sender {
    NSManagedObjectContext *moc = self.managedObjectContext;

    NSString *name = [self.textField stringValue];
    
    NSManagedObject *forgettable = [NSEntityDescription insertNewObjectForEntityForName:@"Forgettable" inManagedObjectContext:moc];
    [forgettable setValue:name forKey:@"name"];
    
    NSError *error = nil;
    if ([moc save:&error] == NO) {
        NSLog(@"Error: %@", error);
    }

    self.forgettables = [self.forgettables arrayByAddingObject:forgettable];

    [self.tableView reloadData];
    
    self.textField.stringValue = @""; // Does *not* invoke NSControlTextDidChangeNotification
    self.addNameButton.enabled = NO;
}

// apontious 12/2/2017: Previously, we used a different context each time we refreshed.
// But I don't want to do that anymore, because I want to switch to NSPersistentContainer, which has its own, single main thread context.
// Turns out, if you don't have a reference to a managed object instance, it will disappear and will be refetched, which is what we want.
- (IBAction)refresh:(id)sender {
    self.forgettables = nil;
    [self.tableView reloadData]; // Needed #1 to immediately, consistently forget the managed object instances.

    // Needed #2 to immediately, consistently forget the managed object instances.
    // Give system a runloop cycle to process that there are no references.
    // This is probably more finicky and time-sensitive than I would like, but it works for now (macOS 10.12).
    dispatch_async(dispatch_get_main_queue(), ^{
        NSManagedObjectContext *moc = self.managedObjectContext;

        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:[NSEntityDescription entityForName:@"Forgettable" inManagedObjectContext:moc]];

        NSError *error;
        NSArray *result = [moc executeFetchRequest:fetchRequest error:&error];

        if (result == nil) {
            // TODO: error handling
            NSLog(@"Error: %@", error);
        }

        self.forgettables = result;
        [self.tableView reloadData];
    });
}

#pragma mark Table Stuff

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.forgettables.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    id result;
    
    NSManagedObject *forgettable = self.forgettables[row];
    
    if ([tableColumn.identifier isEqualToString:@"pointer"] == YES) {
        result = [NSString stringWithFormat:@"%p", forgettable];
    } else if ([tableColumn.identifier isEqualToString:@"name"] == YES) {
        NSString *name = [forgettable valueForKey:@"name"];
        if (name == nil) {
            result = @"(nil)";
        } else {
            result = name;
        }
    }
    
    return result;
}

#pragma mark NSTextFieldDelegate

// apontious 6/16/2012: Only allow adding non-empty names to table, to distinguish from names made nil due to transient property behavior.
- (void)controlTextDidChange:(NSNotification *)notification {
    self.addNameButton.enabled = self.textField.stringValue.length > 0;
}

@end
