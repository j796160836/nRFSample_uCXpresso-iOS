//
//  ViewController.m
//  nRFSample
//
//  Created by Johnny on 1/15/15.
//  Copyright (c) 2015 Johnny. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "UARTPeripheral.h"


typedef enum
{
    IDLE = 0,
    SCANNING,
    CONNECTED,
} ConnectionState;

typedef enum
{
    LOGGING,
    RX,
    TX,
} ConsoleDataType;


@interface ViewController () <UITextFieldDelegate, CBCentralManagerDelegate, UARTPeripheralDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UITextView *consoleTextView;
@property (weak, nonatomic) IBOutlet UITextField *sendTextField;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;

@property (weak, nonatomic) IBOutlet UIButton *leftButton;

@property (weak, nonatomic) IBOutlet UIButton *stopButton;

@property (weak, nonatomic) IBOutlet UIButton *rightButton;

@property (nonatomic, strong) CBCentralManager *cm;
@property (nonatomic) ConnectionState state;
@property (nonatomic, strong) UARTPeripheral *currentPeripheral;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.cm = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    [self addTextToConsole:@"Did start application" dataType:LOGGING];
    
    [self setButtonsEnabled:NO];
}

- (IBAction)connectButtonPressed:(id)sender
{
    [self.sendTextField resignFirstResponder];
    
    switch (self.state) {
        case IDLE:
            self.state = SCANNING;
            
            self.statusLabel.text=@"Status: Scanning...";
            NSLog(@"Started scan ...");
            [self.connectButton setTitle:@"Cancel Scanning" forState:UIControlStateNormal];
            
            [self.cm scanForPeripheralsWithServices:nil options:nil];
            
            
            //            [self.cm scanForPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID] options:@{CBCentralManagerScanOptionAllowDuplicatesKey: [NSNumber numberWithBool:YES]}];
            //            [self.cm
            //             scanForPeripheralsWithServices:@[UARTPeripheral.deviceInformationServiceUUID]
            //             options:nil];
            
            //            [self.cm
            //             scanForPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID]
            //             options:nil];
            break;
            
        case SCANNING:
            self.state = IDLE;
            
            NSLog(@"Stopped scan");
            self.statusLabel.text=@"Status: Ready.";
            [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
            [self setButtonsEnabled:NO];
            
            [self.cm stopScan];
            break;
            
        case CONNECTED:
            self.statusLabel.text=@"Status: Ready.";
            NSLog(@"Disconnect peripheral %@", self.currentPeripheral.peripheral.name);
            [self.cm cancelPeripheralConnection:self.currentPeripheral.peripheral];
            break;
    }
}

- (void) didReadHardwareRevisionString:(NSString *)string
{
    [self addTextToConsole:[NSString stringWithFormat:@"Hardware revision: %@", string] dataType:LOGGING];
}

- (void) didReceiveData:(NSString *)string
{
    [self addTextToConsole:string dataType:RX];
}

- (void) addTextToConsole:(NSString *) string dataType:(ConsoleDataType) dataType
{
    NSString *direction;
    switch (dataType)
    {
        case RX:
            direction = @"RX";
            break;
            
        case TX:
            direction = @"TX";
            break;
            
        case LOGGING:
            direction = @"Log";
    }
    
    NSDateFormatter *formatter;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    
    self.consoleTextView.text = [self.consoleTextView.text stringByAppendingFormat:@"[%@] %@: %@\n",[formatter stringFromDate:[NSDate date]], direction, string];
    
    [self.consoleTextView setScrollEnabled:NO];
    NSRange bottom = NSMakeRange(self.consoleTextView.text.length-1, self.consoleTextView.text.length);
    [self.consoleTextView scrollRangeToVisible:bottom];
    [self.consoleTextView setScrollEnabled:YES];
}

- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        [self.connectButton setEnabled:YES];
    }
    
}

- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Did discover peripheral %@", peripheral.name);
    [self addTextToConsole:[NSString stringWithFormat:@"Found: %@", peripheral.name] dataType:LOGGING];
    
    if([peripheral.name isEqualToString:@"nano11u37"]) {
        [self.cm stopScan];
        
        self.currentPeripheral = [[UARTPeripheral alloc] initWithPeripheral:peripheral delegate:self];
        
        [self.cm connectPeripheral:peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: [NSNumber numberWithBool:YES]}];
    }
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Did connect peripheral %@", peripheral.name);
    
    [self addTextToConsole:[NSString stringWithFormat:@"Did connect to %@", peripheral.name] dataType:LOGGING];
    [self setButtonsEnabled:YES];
    self.state = CONNECTED;
    self.statusLabel.text=@"Status: Connected.";
    [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
    [self.sendButton setUserInteractionEnabled:YES];
    [self.sendTextField setUserInteractionEnabled:YES];
    
    if ([self.currentPeripheral.peripheral isEqual:peripheral])
    {
        [self.currentPeripheral didConnect];
    }
}

- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Did disconnect peripheral %@", peripheral.name);
    self.statusLabel.text=@"Status: Disconnected.";
    [self setButtonsEnabled:NO];
    [self addTextToConsole:[NSString stringWithFormat:@"Did disconnect from %@, error code %ld", peripheral.name, (long)error.code] dataType:LOGGING];
    
    self.state = IDLE;
    
    [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    [self.sendButton setUserInteractionEnabled:NO];
    [self.sendTextField setUserInteractionEnabled:NO];
    
    if ([self.currentPeripheral.peripheral isEqual:peripheral])
    {
        [self.currentPeripheral didDisconnect];
    }
}

- (IBAction)left_button_click:(id)sender {
    [self sendMessage:@"$left#"];
}

- (IBAction)stop_button_click:(id)sender {
    [self sendMessage:@"$stop#"];
}

- (IBAction)right_button_click:(id)sender {
    [self sendMessage:@"$right#"];
}

-(void) setButtonsEnabled:(BOOL)enabled{
    self.leftButton.enabled=enabled;
    self.rightButton.enabled=enabled;
    self.stopButton.enabled=enabled;
}


-(void)sendMessage:(NSString *)msg{
    [self addTextToConsole:msg dataType:TX];
    
    [self.currentPeripheral writeString:msg];
}

@end
