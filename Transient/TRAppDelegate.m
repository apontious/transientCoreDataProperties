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

@property (readonly, nonatomic) NSPersistentContainer *persistentContainer;

@property (nonatomic, copy) NSArray<NSManagedObject *> *forgettables;

@end

@implementation TRAppDelegate

#pragma mark - Core Data stack

@synthesize persistentContainer = _persistentContainer;

- (NSPersistentContainer *)persistentContainer {
    // The persistent container for the application. This implementation creates and returns a container, having loaded the store for the application to it.
    @synchronized (self) {
        if (_persistentContainer == nil) {
            _persistentContainer = [[NSPersistentContainer alloc] initWithName:@"Transient"];

            NSPersistentStoreDescription *storeDescription = [[NSPersistentStoreDescription alloc] init];
            storeDescription.type = NSInMemoryStoreType;
            _persistentContainer.persistentStoreDescriptions = @[storeDescription];

            [_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
                if (error != nil) {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                    /*
                     Typical reasons for an error here include:
                     * The parent directory does not exist, cannot be created, or disallows writing.
                     * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                     * The device is out of space.
                     * The store could not be migrated to the current model version.
                     Check the error message to determine what the actual problem was.
                     */
                    NSLog(@"Unresolved error %@, %@", error, error.userInfo);
                    abort();
                }
            }];
        }
    }

    return _persistentContainer;
}

- (NSManagedObjectContext *)managedObjectContext {
    return self.persistentContainer.viewContext;
}

#pragma mark - Core Data Undo support

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
    return self.persistentContainer.viewContext.undoManager;
}

#pragma mark -

// apontious 6/16/2012: Must use this access point, instead of applicationDidFinishLaunching:, if we want to do things before e.g. table view is populated.
- (void)awakeFromNib {
    [self refresh:nil];
}

#pragma mark Actions

- (IBAction)addName:(id)sender {
    NSManagedObjectContext *moc = self.managedObjectContext;

    NSString *name = self.textField.stringValue;
    
    NSManagedObject *forgettable = [NSEntityDescription insertNewObjectForEntityForName:@"Forgettable" inManagedObjectContext:moc];
    [forgettable setValue:name forKey:@"name"];
    
    NSError *error;
    if ([moc save:&error] == NO) {
        NSLog(@"Error: %@", error);
    }

    self.forgettables = [self.forgettables arrayByAddingObject:forgettable];

    [self.tableView reloadData];
    
    self.textField.stringValue = @""; // Does *not* invoke NSControlTextDidChangeNotification
    self.addNameButton.enabled = NO;
}

// apontious 12/2/2017: Previously, we used a different context each time we refreshed.
// But I don't want to do that anymore, because I have switched to NSPersistentContainer, which has its own, single main thread context.
// Turns out, if you don't have a reference to a managed object instance, it will disappear and will be refetched, which is what we want.
- (IBAction)refresh:(id)sender {
    self.forgettables = nil;

    // Need to do this or lack of current references won't immediately translate into objects being removed from context.
    [self.managedObjectContext processPendingChanges];

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
