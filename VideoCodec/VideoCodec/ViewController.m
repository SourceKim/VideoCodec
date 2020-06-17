////  ViewController.m
//  VideoCodec
//
//  Created by Su Jinjin on 2020/6/17.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView * table;

@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> * demoArray;

@end

NSString * const kCellId = @"cellId";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _table = [[UITableView alloc] initWithFrame: self.view.bounds style: UITableViewStylePlain];
    _table.delegate = self;
    _table.dataSource = self;
    [self.view addSubview: _table];
    
    [_table registerClass: [UITableViewCell class] forCellReuseIdentifier: kCellId];
    
    _demoArray = @ [
                    @{@"1. 解码 MP4 格式": @"DecodeMp4ViewController"},
                    ];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    
    self.title = @"Demo 列表";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: kCellId];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: kCellId];
    }
    
    cell.textLabel.text = _demoArray[indexPath.item].allKeys.firstObject;
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _demoArray.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *vcName = _demoArray[indexPath.item].allValues.firstObject;
    UIViewController *vc = [NSClassFromString(vcName) new];
    vc.view.backgroundColor = UIColor.whiteColor;
    vc.title = _demoArray[indexPath.item].allKeys.firstObject;
    [self.navigationController pushViewController: vc animated:true];
}

@end
