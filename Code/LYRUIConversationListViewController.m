//
//  LYRUIConversationListViewController.m
//  LayerSample
//
//  Created by Kevin Coleman on 8/29/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//

#import <objc/runtime.h>
#import "LYRUIConversationListViewController.h"
#import "LYRUIDataSourceChange.h"
#import "LYRUIConstants.h"
#import "LYRUIConversationDataSource.h"

@interface LYRUIConversationListViewController () <UISearchBarDelegate, UISearchDisplayDelegate, LYRUIConversationDataSourceDelegate>

@property (nonatomic) UISearchBar *searchBar;
@property (nonatomic) UISearchDisplayController *searchController;
@property (nonatomic) NSArray *conversations;
@property (nonatomic) NSMutableArray *filteredConversations;
@property (nonatomic) NSPredicate *searchPredicate;
@property (nonatomic) LYRUIConversationDataSource *conversationListDataSource;
@property (nonatomic) BOOL isOnScreen;

@end

@implementation LYRUIConversationListViewController

static NSString *const LYRUIConversationCellReuseIdentifier = @"conversationCellReuseIdentifier";

+ (instancetype)conversationListViewControllerWithLayerClient:(LYRClient *)layerClient
{
    NSAssert(layerClient, @"layerClient cannot be nil");
    return [[self alloc] initConversationlistViewControllerWithLayerClient:layerClient];
}

- (id)initConversationlistViewControllerWithLayerClient:(LYRClient *)layerClient
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self)  {
        // Set properties from designated initializer
        _layerClient = layerClient;
        
        // Set default configuration for public properties
        _cellClass = [LYRUIConversationTableViewCell class];
        _rowHeight = 72;
        _allowsEditing = TRUE;
        _displaysConversationImage = TRUE;
    }
    return self;
}

- (id) init
{
    [NSException raise:NSInternalInconsistencyException format:@"Failed to call designated initializer"];
    return nil;
}

#pragma mark - VC Lifecycle Methods
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Accessibility
    self.title = @"Messages";
    self.accessibilityLabel = @"Messages";
    
    // Searchbar Setup
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    self.searchBar.accessibilityLabel = @"Search Bar";
    self.searchBar.delegate = self;
    self.searchController = [[UISearchDisplayController alloc] initWithSearchBar:self.searchBar contentsController:self];
    self.searchController.delegate = self;
    self.searchController.searchResultsDelegate = self;
    self.searchController.searchResultsDataSource = self;
    
    //self.tableView.tableHeaderView = self.searchBar;
    //[self.tableView setContentOffset:CGPointMake(0, 44)];
    self.tableView.accessibilityLabel = @"Conversation List";
    
    // DataSoure
    self.conversationListDataSource = [[LYRUIConversationDataSource alloc] initWithLayerClient:self.layerClient];
    self.conversationListDataSource.delegate = self;
    
    // UIAppearace Protocol Config
    [self configureTableViewCellAppearance];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set public configuration properties once view has loaded
    self.tableView.rowHeight = self.rowHeight;
    [self.tableView registerClass:self.cellClass forCellReuseIdentifier:LYRUIConversationCellReuseIdentifier];
    
    self.searchController.searchResultsTableView.rowHeight = self.rowHeight;
    [self.searchController.searchResultsTableView registerClass:self.cellClass forCellReuseIdentifier:LYRUIConversationCellReuseIdentifier];
    
    if (self.allowsEditing) {
        [self addEditButton];
    }
    
    self.isOnScreen = TRUE;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.isOnScreen = NO;
}

#pragma mark - Public setters

- (void)setAllowsEditing:(BOOL)allowsEditing
{
    if (self.isOnScreen) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot set editing mode after the view has been loaded" userInfo:nil];
    }
    _allowsEditing = allowsEditing;

    if (self.navigationItem.leftBarButtonItem && !allowsEditing) {
        self.navigationItem.leftBarButtonItem = nil;
    }
}

- (void)setCellClass:(Class<LYRUIConversationPresenting>)cellClass
{
    if (self.isOnScreen) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot set cellClass after the view has been loaded" userInfo:nil];
    }
    
    if (!class_conformsToProtocol(cellClass, @protocol(LYRUIConversationPresenting))) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cell class cellClass must conform to LYRUIConversationPresenting Protocol" userInfo:nil];

    }
    _cellClass = cellClass;
}

- (void)setRowHeight:(CGFloat)rowHeight
{
    if (self.isOnScreen) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot set rowHeight after the view has been loaded" userInfo:nil];
    }
    _rowHeight = rowHeight;
}

- (void)setDisplaysConversationImage:(BOOL)displaysConversationImage
{
    if (self.isOnScreen) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot set displaysConversationImage after the view has been loaded" userInfo:nil];
    }
    _displaysConversationImage = displaysConversationImage;
}

#pragma mark - Navigation Bar Edit Button

- (void)addEditButton
{
    UIBarButtonItem *editButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Edit"
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(editButtonTapped)];
    editButtonItem.accessibilityLabel = @"Edit";
    self.navigationItem.leftBarButtonItem = editButtonItem;
}

- (void)reloadConversations
{
    if (self.searchController.active) {
        [self.searchController.searchResultsTableView reloadData];
    } else {
        [self.tableView reloadData];
    }
}

// Returns appropriate data set depending on search state
- (NSArray *)currentDataSet
{
    if (self.isSearching) {
        return self.filteredConversations;
    }
    return self.conversationListDataSource.identifiers;
}

- (BOOL)isSearching
{
    return self.searchController.active;
}

#pragma mark - UISearchDisplayDelegate Methods

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller
{
    // We react to search begining
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller
{
    // We respond to ending the search
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    // Hmmm..
}

#pragma mark - Table view data source methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self currentDataSet] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell<LYRUIConversationPresenting> *conversationCell = [tableView dequeueReusableCellWithIdentifier:LYRUIConversationCellReuseIdentifier forIndexPath:indexPath];
    [self configureCell:conversationCell atIndexPath:indexPath];
    return conversationCell;
}

- (void)configureCell:(UITableViewCell<LYRUIConversationPresenting> *)conversationCell atIndexPath:(NSIndexPath *)indexPath
{
    NSURL *conversationID = [[self currentDataSet] objectAtIndex:indexPath.row];
   
    // Present Conversation
    LYRConversation *conversation = [[[self.layerClient conversationsForIdentifiers:[NSSet setWithObject:conversationID]] allObjects] firstObject];
    [conversationCell presentConversation:conversation];
    
    // Update cell with image if needed
    if (self.displaysConversationImage) {
        UIImage *conversationImage = [self.dataSource conversationImageForParticipants:conversation.participants inConversationListViewController:self];
        [conversationCell updateWithConversationImage:conversationImage];
    }
    
    // Update Cell with Label
     NSString *conversationLabel = [self.dataSource conversationLabelForParticipants:conversation.participants inConversationListViewController:self];
    [conversationCell updateWithConversationLabel:conversationLabel];

}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.allowsEditing;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.layerClient deleteConversation:[[self currentDataSet] objectAtIndex:indexPath.row] error:nil];
    }
}

#pragma mark - Table view delegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSURL *conversationID = [[self currentDataSet] objectAtIndex:indexPath.row];
    LYRConversation *conversation = [[[self.layerClient conversationsForIdentifiers:[NSSet setWithObject:conversationID]] allObjects] firstObject];
    [self.delegate conversationListViewController:self didSelectConversation:conversation];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.rowHeight;
}

#pragma mark - Conversation Editing Methods

// Set table view into editing mode and change left bar buttong to a done button
- (void)editButtonTapped
{
    [self.tableView setEditing:TRUE animated:TRUE];
    UIBarButtonItem *doneButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(doneButtonTapped)];
    doneButtonItem.accessibilityLabel = @"Done";
    self.navigationItem.leftBarButtonItem = doneButtonItem;
}

- (void)doneButtonTapped
{
    [self.tableView setEditing:FALSE animated:TRUE];
    [self addEditButton];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

#pragma mark
#pragma mark Notification Observer Delegate Methods

- (void)observerWillChangeContent:(LYRUIConversationDataSource *)observer
{
    //[self.tableView beginUpdates];
}

- (void)observer:(LYRUIConversationDataSource *)observer updateWithChanges:(NSArray *)changes
{
//    NSLog(@"Changes: %@", changes);
//    for (LYRUIDataSourceChange *change in changes) {
//        if (change.type == LYRUIDataSourceChangeTypeUpdate) {
//            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:change.newIndex inSection:0]]
//                                  withRowAnimation:UITableViewRowAnimationAutomatic];
//        } else if (change.type == LYRUIDataSourceChangeTypeInsert) {
//            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:change.newIndex inSection:0]]
//                                  withRowAnimation:UITableViewRowAnimationAutomatic];
//        } else if (change.type == LYRUIDataSourceChangeTypeMove) {
//            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:change.oldIndex inSection:0]]
//                                  withRowAnimation:UITableViewRowAnimationAutomatic];
//            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:change.newIndex inSection:0]]
//                                  withRowAnimation:UITableViewRowAnimationAutomatic];
//        } else if (change.type == LYRUIDataSourceChangeTypeDelete) {
//            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:change.newIndex inSection:0]]
//                                  withRowAnimation:UITableViewRowAnimationAutomatic];
//        }
//    }
}

- (void)observer:(LYRUIConversationDataSource *)observer didChangeContent:(BOOL)didChangeContent
{
//    [self.tableView endUpdates];
    [self.tableView reloadData];
}

- (void)configureTableViewCellAppearance
{
    [[LYRUIConversationTableViewCell appearance] setConversationLabelFont:[UIFont boldSystemFontOfSize:14]];
    [[LYRUIConversationTableViewCell appearance] setConversationLableColor:[UIColor blackColor]];
    [[LYRUIConversationTableViewCell appearance] setLastMessageTextFont:[UIFont systemFontOfSize:12]];
    [[LYRUIConversationTableViewCell appearance] setLastMessageTextColor:[UIColor grayColor]];
    [[LYRUIConversationTableViewCell appearance] setDateLabelFont:[UIFont systemFontOfSize:12]];
    [[LYRUIConversationTableViewCell appearance] setDateLabelColor:[UIColor darkGrayColor]];
    [[LYRUIConversationTableViewCell appearance] setBackgroundColor:[UIColor whiteColor]];
}

@end
