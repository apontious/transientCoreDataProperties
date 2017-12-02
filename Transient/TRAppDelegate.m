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

@property (weak) IBOutlet NSWindow *window;

@property (readonly, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation TRAppDelegate {

@private

    NSArray *_forgettables;

    NSMutableArray *_managedObjectContexts;
}

@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize managedObjectContext = __managedObjectContext;

// Apontious 6/16/2012: Must use this access point, instead of applicationDidFinishLaunching:, if we want to do things before e.g. table view is populated.
- (void)awakeFromNib {
    // Apontious 6/16/2012: We don't want the previous session's data cluttering things up, so delete it.
    NSURL *url = [[self applicationFilesDirectory] URLByAppendingPathComponent:@"Transient.storedata"];
    
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

    _managedObjectContexts = [NSMutableArray array];
    [_managedObjectContexts addObject:self.managedObjectContext];
    [self.managedObjectContext setStalenessInterval:0.0];
}

// Returns the directory the application uses to store the Core Data store file. This code uses a directory named "edge.Transient" in the user's Application Support directory.
- (NSURL *)applicationFilesDirectory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"edge.Transient"];
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
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
    NSError *error = nil;
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] error:&error];
    
    if (properties == nil) {
        BOOL ok = NO;
        if ([error code] == NSFileReadNoSuchFileError) {
            ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        }
        if (ok == NO) {
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    } else {
        if ([[properties objectForKey:NSURLIsDirectoryKey] boolValue] == NO) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"Transient.storedata"];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![coordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]) {
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
    __managedObjectContext = [[NSManagedObjectContext alloc] init];
    [__managedObjectContext setPersistentStoreCoordinator:coordinator];

    return __managedObjectContext;
}

// Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}

#pragma mark Actions

- (IBAction)addName:(id)sender {
    NSManagedObjectContext *moc = [_managedObjectContexts lastObject];

    NSString *name = [self.textField stringValue];
    
    NSManagedObject *forgettable = [NSEntityDescription insertNewObjectForEntityForName:@"Forgettable" inManagedObjectContext:moc];
    [forgettable setValue:name forKey:@"name"];
    
    NSError *error = nil;
    if ([moc save:&error] == NO) {
        NSLog(@"Error: %@", error);
    }

    [self.tableView reloadData];
    
    [self.textField setStringValue:@""];
}

// apontious 6/16/2012: Each time we refresh, we switch to a different context, so that we'll get new instances of the managed objects. This tests whether transient properties are actually remembered by the database, or are just associated with individual instances, the same way ivars would be.
- (IBAction)refresh:(id)sender {
    NSManagedObjectContext *newManagedObjectContext = [[NSManagedObjectContext alloc] init];
    [newManagedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    [_managedObjectContexts addObject:newManagedObjectContext];

    [self.tableView reloadData];
}

#pragma mark Table Stuff
    
- (NSArray *)forgettables {
    NSManagedObjectContext *moc = [_managedObjectContexts lastObject];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Forgettable" inManagedObjectContext:moc]];

    NSError *error = nil;
    NSArray *result = [moc executeFetchRequest:fetchRequest error:&error];
    
    if (result == nil) {
        // TODO: error handling
        NSLog(@"Error: %@", error);
    }
    
    result = [result sortedArrayUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]]];
    
    return result;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.forgettables count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    id result = nil;
    
    NSManagedObject *forgettable = [self.forgettables objectAtIndex:row];
    
    if ([[tableColumn identifier] isEqualToString:@"pointer"] == YES) {
        result = [NSString stringWithFormat:@"%p", forgettable];
    } else if ([[tableColumn identifier] isEqualToString:@"name"] == YES) {
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
    [self.addNameButton setEnabled:[[self.textField stringValue] length] > 0];
}

@end
