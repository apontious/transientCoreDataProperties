//
//  TRAppDelegate.h
//  Transient Core Data Properties http://github.com/apontious/transientCoreDataProperties
//
//  Created by Andrew Pontious on 6/16/12.
//  Copyright (c) 2012 Andrew Pontious.
//  Some right reserved: http://opensource.org/licenses/mit-license.php
//

#import <Cocoa/Cocoa.h>

@interface TRAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate> {

@private
    
    NSButton *_addNameButton;
    NSTextField *_textField;
    NSTableView *_tableView;
    
    NSArray *_forgettables;
    
    NSMutableArray *_managedObjectContexts;
}

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
