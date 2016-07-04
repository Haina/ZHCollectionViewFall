//
//  ViewController.m
//  ZHCollectionViewFall
//
//  Created by 张凤娟 on 16/6/30.
//  Copyright © 2016年 张凤娟. All rights reserved.
//

#import "ViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DDCollectionViewFlowLayout.h"
#import <MJRefresh/MJRefresh.h>

@interface ZHPhotoCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *photoImage;

@end

@implementation ZHPhotoCell

@end

@interface ViewController ()<UICollectionViewDataSource,UICollectionViewDelegate,DDCollectionViewDelegateFlowLayout>
{
    NSMutableArray *dataList;
    NSMutableArray *sectionOne;
    NSInteger columns;
}

@property (nonatomic, strong) ALAssetsLibrary *assetLibrary;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"照片瀑布流";
    columns = 3;
    if(!dataList)
        dataList = [[NSMutableArray alloc] initWithCapacity:0];
    [dataList removeAllObjects];
    
    DDCollectionViewFlowLayout *layout = [[DDCollectionViewFlowLayout alloc] init];
    layout.delegate = self;
    [self.collectionView setCollectionViewLayout:layout];
    
    [self loadAssets];
    [self setFooterAndHeaderRefresh];
}

- (void)endHeaderRefresh{
    [self.collectionView.mj_header endRefreshing];
}

- (void)setFooterAndHeaderRefresh{
    
    //顶部刷新
    self.collectionView.mj_header = [MJRefreshNormalHeader headerWithRefreshingBlock:^{
        [self loadAssets];
    }];
    
    //底部刷新
    self.collectionView.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingBlock:^{
        [dataList addObjectsFromArray:dataList];
        [self.collectionView.mj_footer endRefreshing];
        [self.collectionView reloadData];
    }];
}

#pragma mark - UICollectionView DataSource Methods

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return dataList.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView layout:(DDCollectionViewFlowLayout *)layout numberOfColumnsInSection:(NSInteger)section{
    return columns;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellReuseIdentifier = @"PhotoCell";
    ZHPhotoCell *cell = (ZHPhotoCell *)[collectionView dequeueReusableCellWithReuseIdentifier:cellReuseIdentifier forIndexPath:indexPath];
    ALAsset *set = dataList[indexPath.item];
    [cell.photoImage setImage:[UIImage imageWithCGImage:set.aspectRatioThumbnail]];
    return cell;
}

#pragma mark - UICollectionView Delegate Methods

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    return 5;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    return 5;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(5, 5, 5, 5);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    ALAsset *set = dataList[indexPath.item];
    UIImage *image = [UIImage imageWithCGImage:set.aspectRatioThumbnail];
    CGFloat aflat = image.size.width/image.size.height;
    NSLog(@"imageSize: %@",NSStringFromCGSize(image.size));
    UIEdgeInsets sectionInsets = [self collectionView:collectionView layout:collectionViewLayout insetForSectionAtIndex:indexPath.section];
    CGFloat itemWidth = CGRectGetWidth(collectionView.frame) - (sectionInsets.left + sectionInsets.right);
    NSInteger numberOfColumns = columns;
    CGFloat interitemSpacing = [self collectionView:collectionView layout:collectionViewLayout minimumInteritemSpacingForSectionAtIndex:indexPath.section];
    CGFloat columnSpace = itemWidth - (interitemSpacing * (numberOfColumns - 1));
    CGFloat columnWidth = (columnSpace/numberOfColumns);
    return CGSizeMake(columnWidth, columnWidth/aflat);
    //    return CGSizeMake(100, 100 + indexPath.item % 20);
}

- (void)loadAssets {
    
    // Initialise
    dataList = [NSMutableArray new];
    _assetLibrary = [[ALAssetsLibrary alloc] init];
    
    // Run in the background as it takes a while to get all assets from the library
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSMutableArray *assetGroups = [[NSMutableArray alloc] init];
        NSMutableArray *assetURLDictionaries = [[NSMutableArray alloc] init];
        
        // Process assets
        void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *result, NSUInteger index, BOOL *stop) {
            if (result != nil) {
                if ([[result valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypePhoto]) {
                    [assetURLDictionaries addObject:[result valueForProperty:ALAssetPropertyURLs]];
                    NSURL *url = result.defaultRepresentation.url;
                    [_assetLibrary assetForURL:url
                                   resultBlock:^(ALAsset *asset) {
                                       if (asset) {
                                           @synchronized(dataList) {
                                               [dataList addObject:asset];
                                           }
                                       }
                                   }
                                  failureBlock:^(NSError *error){
                                      NSLog(@"operation was not successfull!");
                                  }];
                    
                }
            }
        };
        
        // Process groups
        void (^ assetGroupEnumerator) (ALAssetsGroup *, BOOL *) = ^(ALAssetsGroup *group, BOOL *stop) {
            if (group != nil) {
                [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:assetEnumerator];
                [assetGroups addObject:group];
            }
            if (dataList.count > 0) {
                // Added first asset so reload data
                [self.collectionView.mj_header performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:NO];
                [self.collectionView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
            }
        };
        
        // Process!
        [self.assetLibrary enumerateGroupsWithTypes:ALAssetsGroupAll
                                         usingBlock:assetGroupEnumerator
                                       failureBlock:^(NSError *error) {
                                           NSLog(@"There is an error");
                                       }];
        
    });
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
