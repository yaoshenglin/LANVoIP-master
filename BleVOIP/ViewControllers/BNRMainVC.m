//
//  BNRMainVC.m
//  BleVOIP
//  主页
//  Created by JustinYang on 7/4/16.
//  Copyright © 2016 JustinYang. All rights reserved.
//

#import "BNRMainVC.h"
#import "BNRCommication.h"
#import "BNRConnectVC.h"
#import "CTB.h"

@interface BNRMainVC ()

@end

@implementation BNRMainVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"主页";
    //self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(didReceiveMemoryWarning)];
    // Do any additional setup after loading the view.
    
    self.navigationItem.rightBarButtonItem = [CTB BarButtonWithTitle:@"测试" target:self tag:1];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)pushToConnectVC:(UIButton *)sender
{
    //进入下一页
    UIStoryboard *SB = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    BNRConnectVC *vc = [SB instantiateViewControllerWithIdentifier:@"connectVC"];
    if ([sender.currentTitle isEqualToString:@"Host"]) {
        vc.roleType = RoleTypeHost;
    }else{
        vc.roleType = RoleTypeClient;
    }
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)ButtonEvents:(UIButton *)button
{
    if (button.tag == 1) {
        //push to chat vc
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UIViewController *vc = [sb instantiateViewControllerWithIdentifier:@"chatrRoomVC"];
        [vc setValue:@(RoleTypeSelf) forKey:@"roleType"];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
