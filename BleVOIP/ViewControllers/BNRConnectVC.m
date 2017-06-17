//
//  BNRPeripheralTVC.m
//  BleChatRoom
//  连接
//  Created by JustinYang on 11/29/15.
//  Copyright © 2015 JustinYang. All rights reserved.
//

#import "BNRConnectVC.h"
#import "CTB.h"
#import "BNRClient.h"
#import "BNRServer.h"
#import "BNRChatRoomVC.h"
#import "MBProgressHUD.h"

@interface BNRConnectVC ()<BNRClientDelegate,BNRServerDelegate>

@property (nonatomic,weak) BNRCommication *manager;

@property (nonatomic,strong) NSMutableArray *peersArr;

@property (nonatomic,copy)  NSString        *tips;

@end

@implementation BNRConnectVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"连接列表";
    // Uncomment the following line to preserve selection between presentations.
    self.clearsSelectionOnViewWillAppear = NO;
    if (self.roleType == RoleTypeClient) {
        self.manager = [BNRClient sharedInstance];
        [(BNRClient *)self.manager startSearchingServers];
    }else{
        self.manager = [BNRServer sharedInstance];
        [(BNRServer *)self.manager startAdvertiserWithDic:@{@"info":@"join us"}];
    }
    self.manager.delegate = self;
    if (self.roleType == RoleTypeHost) {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
        [btn setTitle:@"通话" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(lanuch:) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *btnItem = [[UIBarButtonItem alloc] initWithCustomView:btn];
        self.navigationItem.rightBarButtonItem = btnItem;
    }
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(back:)];
//    @weakify(self);
//    [[RACObserve(self, _tips) skip:1] subscribeNext:^(id x) {
//        @strongify(self);
//        if (self.tips) {
//            MBProgressHUD *loadHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
//            loadHUD.labelText = self.tips;
//        }else{
//            [MBProgressHUD hideHUDForView:self.view animated:YES];
//        }
//    }];
}

- (void)setTips:(NSString *)tips
{
    _tips = tips;
    if (tips) {
        MBProgressHUD *loadHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        loadHUD.labelText = self.tips;
    }else{
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }
}

- (void)back:(id)btn
{
    if (self.roleType == RoleTypeHost) {
        [(BNRServer *)self.manager stopAdvertiser];//主机广播
    }else{
        [(BNRClient *)self.manager stopSearchingServers];//客户端停止搜索
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)lanuch:(UIButton *)btn
{
    //通话
    if (self.manager.session.connectedPeers.count > 0) {
        //push to chat vc
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        BNRChatRoomVC *vc = [sb instantiateViewControllerWithIdentifier:@"chatrRoomVC"];
        vc.roleType = self.roleType;
        vc.manager = self.manager;
        [self.navigationController pushViewController:vc animated:YES];
        
    }else{
        [self autoDismissTips:@"人数必须大于0,才能聊天"];
    }
}

- (void)autoDismissTips:(NSString *)tips
{
    self.tips = nil;
    self.tips = tips;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.tips = nil;
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSMutableArray *)peersArr
{
    if (!_peersArr) {
        _peersArr = [NSMutableArray array];
    }
    return _peersArr;
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.peersArr.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    MCPeerID *peer = self.peersArr[indexPath.row];
    cell.textLabel.text = peer.displayName;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //选择主机收到的添加请求
    if (self.roleType == RoleTypeHost) {
        return;
    }
    self.tips = @"connecting";
    MCPeerID *peerID = self.peersArr[indexPath.row];
    [[BNRClient sharedInstance] connectAvailableServer:peerID];
}

#pragma BNRServerDelegate
- (void)server:(BNRServer *)server peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    //连接状态发生变化
    if (state == MCSessionStateNotConnected) {
        //没有连接
        NSLog(@"没有连接");
        [MBProgressHUD hideHUDForView:self.view animated:NO];
        [self.peersArr enumerateObjectsUsingBlock:^(MCPeerID *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([peerID.displayName isEqualToString:obj.displayName]) {
                *stop = YES;
                [self.peersArr removeObjectAtIndex:idx];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
            }
        }];
    }
    else if(state == MCSessionStateConnected) {
        //已经连接
        NSLog(@"已经连接");
        [MBProgressHUD hideHUDForView:self.view animated:NO];
        __block BOOL reaptedPeer = NO;
        [self.peersArr enumerateObjectsUsingBlock:^(MCPeerID *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([peerID.displayName isEqualToString:obj.displayName]) {
                *stop = YES;
                reaptedPeer = YES;
                [self.peersArr replaceObjectAtIndex:idx withObject:peerID];
            }
        }];
        if (reaptedPeer == NO) {
            [self.peersArr addObject:peerID];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
    else if(state == MCSessionStateConnecting) {
        //正在连接
        NSLog(@"正在连接");
        MBProgressHUD *loadHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        loadHUD.labelText = @"Connecting……";
    }
}

#pragma BNRClientDelegate
- (void)client:(BNRClient *)client foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    //发现附近的用户
    __block BOOL reaptedServe = NO;
    [self.peersArr enumerateObjectsUsingBlock:^(MCPeerID *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
    {
        if ([peerID.displayName isEqualToString:obj.displayName]) {
            *stop = YES;
            reaptedServe = YES;
        }
    }];
    if (reaptedServe) {
        return;
    }
    [self.peersArr addObject:peerID];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)client:(BNRClient *)client lostPeer:(MCPeerID *)peerID
{
    //某个用户消失了
    [self.peersArr enumerateObjectsUsingBlock:^(MCPeerID *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([peerID.displayName isEqualToString:obj.displayName]) {
            [self.peersArr removeObjectAtIndex:idx];
            *stop = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }];
}

- (void)client:(BNRClient *)client connectServerStateChange:(MCSessionState)state
{
    if (state == MCSessionStateConnected) {
        self.tips = nil;
        //push to chat vc
        dispatch_async(dispatch_get_main_queue(), ^{
            UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
            BNRChatRoomVC *vc = [sb instantiateViewControllerWithIdentifier:@"chatrRoomVC"];
            vc.roleType = self.roleType;
            vc.manager = self.manager;
            [self.navigationController pushViewController:vc animated:YES];
        });
    }
    else if(state == MCSessionStateNotConnected) {
        [self autoDismissTips:@"connect fail"];
    }
}

@end
