//
//  ViewController.m
//  Ble_Demo
//
//  Created by double on 2017/6/2.
//  Copyright © 2017年 double. All rights reserved.
//

#import "ViewController.h"
#import "CCBleManager.h"

#define BleTableViewCellIdentifier @"BleTableViewCellIdentifier"

@interface ViewController ()<UITableViewDataSource,UITableViewDelegate>
{
    NSMutableArray *_devices;
    
    CBPeripheral *_currentPeripheral;   //当前设备
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _devices = @[].mutableCopy;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:BleTableViewCellIdentifier];
    
    [self bleManagerCallback];
    
    /*
     友情提示，下拉可以刷新
     */
    
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _devices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:BleTableViewCellIdentifier];
    
    CBPeripheral *peripheral = _devices[indexPath.row];
    
    cell.textLabel.text = peripheral.name;
    cell.detailTextLabel.text = peripheral.identifier.UUIDString;
    
    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    CBPeripheral *peripheral = _devices[indexPath.row];
    
    [self connectWith:peripheral];
}


#pragma mark - UIScrollViewDelegate
//滑动tableView手指离开时
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset{
    
    if (scrollView.contentOffset.y < 50.0f) {
        [self startScan];
    }
}

#pragma mark - Interaction Event
- (void)startScan {
    
    NSLog(@"开始扫描");
    
    [_devices removeAllObjects];
    
    [[CCBleManager shareInstance] scanForPeripheralWithServices:nil options:nil withBlock:^(CBPeripheral *peripheral, NSDictionary<NSString *,id> *advertisementData) {
        
        if ([[CCBleManager shareInstance].reConnectDevices containsObject:peripheral.identifier.UUIDString]) {
            NSLog(@"发现已连接过的设备!");
            
            [self connectWith:peripheral];
        }
        
        if (peripheral.name == nil) {
            return ;
        }
        
        NSLog(@"发现设备: %@,%@",peripheral.name,peripheral.identifier.UUIDString);
        
        if (![_devices containsObject:peripheral]) {
            [_devices addObject:peripheral];
            [self.tableView reloadData];
        }
    }];
    
}

- (void)connectWith:(CBPeripheral *)peripheral {
    
    //连接设备...
    [[CCBleManager shareInstance] connectPeripheral:peripheral options:nil withSuccess:^(CBPeripheral *peripheral) {
        
        //连接成功，存储设备
        [[CCBleManager shareInstance] addReConnectDeviceForUUIDString:peripheral.identifier.UUIDString];
        
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            [[CCBleManager shareInstance] readRSSIWith:peripheral block:^(CBPeripheral *peripheral, NSNumber *RSSI) {
                NSLog(@"设备名: %@,RSSI值: %@",peripheral.name,RSSI);
            }];
        }];
                
        _currentPeripheral = peripheral;
        
        //搜索设备服务... (可筛选只搜索指定服务)
        [[CCBleManager shareInstance] discoverServices:nil withPeripheral:peripheral withBlock:^(CBPeripheral *peripheral, NSError *error) {
            
            //发现服务，开始查找特征...    (可筛选只查找指定特征)
            for (CBService *service in peripheral.services) {
                
                NSLog(@"发现服务: %@",service.UUID);
                [[CCBleManager shareInstance] discoverCharacteristics:nil forService:service withPeripheral:peripheral withBlock:^(CBService *service, NSError *error) {
                    
                    //发现特征，开始订阅监听...
                    for (CBCharacteristic *characteristic in service.characteristics) {
                        
                        NSLog(@"发现特征: %@",characteristic.UUID);
                        [[CCBleManager shareInstance] setNotifyValue:YES forCharacteristic:characteristic withPeripheral:peripheral withBlock:^(CBCharacteristic *characteristic, NSError *error) {
                            
                            if (error) {
                                NSLog(@"订阅失败...");
                                return;
                            }
                            
                            NSData *data = characteristic.value;
                            Byte *bytes = (Byte *)data.bytes;
                            int value = bytes[0];
                            NSLog(@"value: %d",value);
                            
                            if (value == 2) {
                                [[NSNotificationCenter defaultCenter] postNotificationName:@"receiveData" object:nil];
                            }
                        }];
                    }
                }];
            }
        }];
        
    } fail:^(CBPeripheral *peripheral, NSError *error) {
        
        NSLog(@"连接失败");
    } disConnect:^(CBPeripheral *peripheral, NSError *error) {
        NSLog(@"断开连接");
        _currentPeripheral = nil;
        
        [self startScan];
    }];
}

- (IBAction)writeEvent:(id)sender {
    
    if (!_currentPeripheral) {
        return;
    }
    
    //写入数据到设备，这里根据不同设备服务和特征的选择都会不同
    static int alert = 0;
    alert = alert == 2 ? 0 : 2;
    
    Byte byte[1] = {alert};
    NSData *data = [NSData dataWithBytes:byte length:1];
    
    for (CBService *service in _currentPeripheral.services) {
        
        if ([service.UUID isEqual:[CBUUID UUIDWithString:@"****"]]) {
            
            for (CBCharacteristic *characteristic in service.characteristics) {
                
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"****"]]) {
                    
                    [[CCBleManager shareInstance] writeValue:data
                                           forCharacteristic:characteristic
                                                        type:CBCharacteristicWriteWithoutResponse
                                              withPeripheral:_currentPeripheral
                                                   withBlock:^(CBCharacteristic *characterisic, NSError *error) {
                                                       if (!error) {
                                                           NSLog(@"写入成功");
                                                       }
                                                   }];
                    
                    return;
                }
            }
        }
    }
    
}

#pragma mark - APIs
- (void)bleManagerCallback {
    [CCBleManager shareInstance].updateStateBlock = ^(CBManagerState state) {
        NSLog(@"蓝牙状态改变");
        
        if (state == CBManagerStatePoweredOn) {
            [self startScan];
        }
    };
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

