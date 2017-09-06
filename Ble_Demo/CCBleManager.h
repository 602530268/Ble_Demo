//
//  CCBleManager.h
//  BLK_iTag
//
//  Created by double on 2017/7/31.
//  Copyright © 2017年 double. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

typedef void(^CCDidUpdateState)(CBManagerState state);  //蓝牙状态
typedef void(^CCDidDiscoverPeripheral)(CBPeripheral *peripheral);   //发现新设备
typedef void(^CCDidConnectPeripheral)(CBPeripheral *peripheral);    //连接成功
typedef void(^CCDidFailToConnectPerippheral)(CBPeripheral *peripheral, NSError *error); //连接失败
typedef void(^CCDidDisconnectPeripheral)(CBPeripheral *peripheral, NSError *error); //断开连接
typedef void(^CCDidDiscoverServices)(CBPeripheral *peripheral, NSError *error); //发现服务
typedef void(^CCDidDiscoverCharacteristicsForService)(CBService *service, NSError *error);  //发现特征
typedef void(^CCDidUpdateValueForCharacteristic)(CBCharacteristic *characteristic, NSError *error); //设备数据回调
typedef void(^CCDidWriteValueForCharacteristic)(CBCharacteristic *characterisic, NSError *error);   //写入数据完成回调

typedef void(^CCDidFindReConnectPeripheral)(CBPeripheral *peripheral); //发现可重连设备

@interface CCBleManager : NSObject

@property(nonatomic,strong) CBCentralManager *centralManager;

@property(nonatomic,copy) CCDidUpdateState updateStateBlock;    //蓝牙状态改变回调
//@property(nonatomic,copy) CCDidFindReConnectPeripheral findReConnectPeripheralBlock;    //发现存储过的设备(已注释，在搜索到设备那里判断即可)
@property(nonatomic,strong) NSMutableArray *reConnectDevices;   //存储过的设备

+ (CCBleManager *)shareInstance;

//扫描设备
- (void)scanForPeripheralWithServices:(NSArray *)serviceUUIDs
                               options:(NSDictionary <NSString *, id> *)options
                             withBlock:(CCDidDiscoverPeripheral)block;

//停止扫描
- (void)stopScan;

//连接设备
- (void)connectPeripheral:(CBPeripheral *)peripheral
                  options:(NSDictionary <NSString *, id> *)options
         withSuccess:(CCDidConnectPeripheral)success
                     fail:(CCDidFailToConnectPerippheral)fail
               disConnect:(CCDidDisconnectPeripheral)disConnect;

//断开设备
- (void)cancelPeripheralConnectionWithPeripheral:(CBPeripheral *)peripheral;

//查找服务
- (void)discoverServices:(NSArray<CBUUID *> *)serviceUUIDs
          withPeripheral:(CBPeripheral *)peripheral
               withBlock:(CCDidDiscoverServices)block;


//查找特征
- (void)discoverCharacteristics:(NSArray<CBUUID *> *)characteristicUUIDs
                     forService:(CBService *)service
                 withPeripheral:(CBPeripheral *)peripheral
                      withBlock:(CCDidDiscoverCharacteristicsForService)block;

//订阅特征
- (void)setNotifyValue:(BOOL)enabled
     forCharacteristic:(CBCharacteristic *)characteristic
        withPeripheral:(CBPeripheral *)peripheral
             withBlock:(CCDidUpdateValueForCharacteristic)block;

//写入数据
- (void)writeValue:(NSData *)data
 forCharacteristic:(CBCharacteristic *)characteristic
              type:(CBCharacteristicWriteType)type
    withPeripheral:(CBPeripheral *)peripheral
         withBlock:(CCDidWriteValueForCharacteristic)block;

//重置block块
- (void)resetBlocks;

//添加可重连设备
- (void)addReConnectDeviceForUUIDString:(NSString *)UUIDString;

//移除可重连设备
- (void)removeReConnectDeviceForUUIDString:(NSString *)UUIDString;

//删除所有设备
- (void)removeAllDevices;


@end
