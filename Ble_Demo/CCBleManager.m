//
//  CCBleManager.m
//  BLK_iTag
//
//  Created by double on 2017/7/31.
//  Copyright © 2017年 double. All rights reserved.
//

#import "CCBleManager.h"

static NSString *kReConnectDeviceUUIDs = @"kReConnectDeviceUUIDs";  //已存储设备

@interface CCBleManager ()<CBCentralManagerDelegate,CBPeripheralDelegate>
{
    CCDidDiscoverPeripheral _didDiscoverPeripheralBlock;
    CCDidConnectPeripheral _didConnectPeripheralBlock;
    CCDidFailToConnectPerippheral _didFailToConnectPerippheralBlock;
    CCDidDisconnectPeripheral _didDisconnectPeripheralBlock;
    CCDidDiscoverServices _didDiscoverServicesBlock;
    CCDidDiscoverCharacteristicsForService _didDiscoverCharacteristicsForServiceBlock;
    CCDidUpdateValueForCharacteristic _didUpdateValueForCharacteristicBlock;
    CCDidWriteValueForCharacteristic _didWriteValueForCharacteristicBlock;
}

@end

@implementation CCBleManager

static CCBleManager *manager;
+ (CCBleManager *)shareInstance {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[CCBleManager alloc] init];
        [manager registerDelegate];
    });
    return manager;
}

- (void)registerDelegate {
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (void)resetBlocks {
    _didDiscoverPeripheralBlock = nil;
    _didConnectPeripheralBlock = nil;
    _didFailToConnectPerippheralBlock = nil;
    _didDisconnectPeripheralBlock = nil;
    _didDiscoverServicesBlock = nil;
    _didDiscoverCharacteristicsForServiceBlock = nil;
    _didUpdateValueForCharacteristicBlock = nil;
    _didWriteValueForCharacteristicBlock = nil;
    _findReConnectPeripheralBlock = nil;
}

#pragma mark - APIs (public)
//扫描设备
- (void)scanForPeripheralWithServices:(NSArray *)serviceUUIDs
                               options:(NSDictionary <NSString *, id> *)options
                             withBlock:(CCDidDiscoverPeripheral)block {
    
    NSLog(@"scanForPeripheralWithServices");
    _didDiscoverPeripheralBlock = block;
    if (self.centralManager.state == CBManagerStatePoweredOn) {
        [self.centralManager scanForPeripheralsWithServices:serviceUUIDs options:options];
    }
}

//停止扫描
- (void)stopScan {
    NSLog(@"stopScan");
    [self.centralManager stopScan];
}

//连接设备
- (void)connectPeripheral:(CBPeripheral *)peripheral
                  options:(NSDictionary <NSString *, id> *)options
                withSuccess:(CCDidConnectPeripheral)success
                     fail:(CCDidFailToConnectPerippheral)fail
               disConnect:(CCDidDisconnectPeripheral)disConnect {
    
    _didConnectPeripheralBlock = success;
    _didFailToConnectPerippheralBlock = fail;
    _didDisconnectPeripheralBlock = disConnect;
    
    [self.centralManager connectPeripheral:peripheral options:options];
}

//断开设备
- (void)cancelPeripheralConnectionWithPeripheral:(CBPeripheral *)peripheral {
    
    if (!peripheral) {
        return;
    }
    
    [self removeReConnectDeviceForUUIDString:peripheral.identifier.UUIDString];
    [self.centralManager cancelPeripheralConnection:peripheral];
}

//查找服务
- (void)discoverServices:(NSArray<CBUUID *> *)serviceUUIDs
          withPeripheral:(CBPeripheral *)peripheral
               withBlock:(CCDidDiscoverServices)block {
    
    _didDiscoverServicesBlock = block;
    peripheral.delegate = self;
    [peripheral discoverServices:serviceUUIDs];
}


//查找特征
- (void)discoverCharacteristics:(NSArray<CBUUID *> *)characteristicUUIDs
                     forService:(CBService *)service
                 withPeripheral:(CBPeripheral *)peripheral
                      withBlock:(CCDidDiscoverCharacteristicsForService)block {
    
    _didDiscoverCharacteristicsForServiceBlock = block;
    
    [peripheral discoverCharacteristics:characteristicUUIDs forService:service];
}

//订阅特征
- (void)setNotifyValue:(BOOL)enabled
     forCharacteristic:(CBCharacteristic *)characteristic
        withPeripheral:(CBPeripheral *)peripheral
             withBlock:(CCDidUpdateValueForCharacteristic)block {
    
    _didUpdateValueForCharacteristicBlock = block;
    
    [peripheral setNotifyValue:enabled forCharacteristic:characteristic];
}

//写入数据
- (void)writeValue:(NSData *)data
 forCharacteristic:(CBCharacteristic *)characteristic
              type:(CBCharacteristicWriteType)type
    withPeripheral:(CBPeripheral *)peripheral
         withBlock:(CCDidWriteValueForCharacteristic)block {
    
    _didWriteValueForCharacteristicBlock = block;
    
    [peripheral writeValue:data forCharacteristic:characteristic type:type];
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    switch (central.state) {
        case CBManagerStateUnknown: {
            NSLog(@"CBManagerStateUnknown");
            break;
        }
        case CBManagerStateResetting: {
            NSLog(@"CBManagerStateResetting");
            break;
        }
        case CBManagerStateUnsupported: {
            NSLog(@"CBManagerStateUnsupported");
            break;
        }
        case CBManagerStateUnauthorized: {
            NSLog(@"CBManagerStateUnauthorized");
            break;
        }
        case CBManagerStatePoweredOff: {
            NSLog(@"CBManagerStatePoweredOff");
            break;
        }
        case CBManagerStatePoweredOn: {
            NSLog(@"CBManagerStatePoweredOn");
            break;
        }
    }
    
    if (_updateStateBlock) {
        _updateStateBlock(central.state);
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
//    NSLog(@"didDiscoverPeripheral: %@",peripheral);

    if (_didDiscoverPeripheralBlock) {
        _didDiscoverPeripheralBlock(peripheral);
    }
    
    return;
    if ([self.reConnectDevices containsObject:peripheral.identifier.UUIDString]) {
        NSLog(@"发现可重连设备...");
        
        if (_findReConnectPeripheralBlock) {
            _findReConnectPeripheralBlock(peripheral);
            return;
        }
    }
    
    if (self.reConnectDevices.count) {
        NSLog(@"有绑定过设备，不允许连接其他设备");
        return;
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
//    NSLog(@"didConnectPeripheral...");
    
    [self.centralManager stopScan];
    
    if (_didConnectPeripheralBlock) {
        _didConnectPeripheralBlock(peripheral);
    }
    
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
//    NSLog(@"didFailToConnectPeripheral");
    
    if (_didFailToConnectPerippheralBlock) {
        _didFailToConnectPerippheralBlock(peripheral, error);
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
//    NSLog(@"didDisconnectPeripheral");
    
    if (_didDisconnectPeripheralBlock) {
        _didDisconnectPeripheralBlock(peripheral, error);
    }
}

#pragma mark - CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
//    NSLog(@"didDiscoverServices...");
    
    if (_didDiscoverServicesBlock) {
        _didDiscoverServicesBlock(peripheral, error);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
//    NSLog(@"didDiscoverCharacteristicsForService");
    
    if (_didDiscoverCharacteristicsForServiceBlock) {
        _didDiscoverCharacteristicsForServiceBlock(service, error);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
//    NSLog(@"didUpdateValueForCharacteristic");
    
    if (_didUpdateValueForCharacteristicBlock) {
        _didUpdateValueForCharacteristicBlock(characteristic, error);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
//    NSLog(@"didWriteValueForCharacteristic");
    
    if (_didWriteValueForCharacteristicBlock) {
        _didWriteValueForCharacteristicBlock(characteristic, error);
    }
}


#pragma mark - Lazy load
- (NSMutableArray *)reConnectDevices {
    if (!_reConnectDevices) {
        _reConnectDevices = [[[NSUserDefaults standardUserDefaults] objectForKey:kReConnectDeviceUUIDs] mutableCopy];
        if (!_reConnectDevices) {
            _reConnectDevices = @[].mutableCopy;
        }
    }
    return _reConnectDevices;
}

#pragma mark - ReConnect APIs
- (void)addReConnectDeviceForUUIDString:(NSString *)UUIDString {
    if ([self.reConnectDevices containsObject:UUIDString]) {
        return;
    }
    
    [self.reConnectDevices addObject:UUIDString];
    
    [self saveReConnectDevices];
}

- (void)removeReConnectDeviceForUUIDString:(NSString *)UUIDString {
    if ([self.reConnectDevices containsObject:UUIDString]) {
        [self.reConnectDevices removeObject:UUIDString];
        
        [self saveReConnectDevices];
    }
}

- (void)removeAllDevices {
    [self.reConnectDevices removeAllObjects];
    
    [self saveReConnectDevices];
}

- (void)saveReConnectDevices {
    [[NSUserDefaults standardUserDefaults] setObject:self.reConnectDevices forKey:kReConnectDeviceUUIDs];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end
