//
//  ViewController.m
//  ECBTSample
//
//  Created by Orcun on 22/08/2018.
//  Copyright © 2018 Orcun. All rights reserved.
//

#import "ViewController.h"
#import "BraintreeCore/BraintreeCore.h"
#import "BraintreePayPal/BraintreePayPal.h"



@interface ViewController () <BTAppSwitchDelegate, BTViewControllerPresentingDelegate>
@property (nonatomic, strong) BTAPIClient *braintreeClient;
@property (nonatomic, strong) BTPayPalDriver *payPalDriver;

@end

@implementation ViewController
NSString *clientToken;
NSString *resultCheck;
NSString *amount;
double price;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSURL *clientTokenURL = [NSURL URLWithString:@"http://orcodevbox.co.uk/max/token.php"];
    NSMutableURLRequest *clientTokenRequest = [NSMutableURLRequest requestWithURL:clientTokenURL];
    [clientTokenRequest setValue:@"text/plain" forHTTPHeaderField:@"Accept"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:clientTokenRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // TODO: Handle errors
        clientToken = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        // Log the client token to confirm that it is returned from the server
        NSLog(@"%@",clientToken);
        self.braintreeClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];
        // As an example, you may wish to present our Drop-in UI at this point.
        // Continue to the next section to learn more...
    }] resume];
}
- (IBAction)launchPaypal:(id)sender {
    // Example: Initialize BTAPIClient, if you haven't already
    self.braintreeClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];
    BTPayPalDriver *payPalDriver = [[BTPayPalDriver alloc] initWithAPIClient:self.braintreeClient];
    payPalDriver.viewControllerPresentingDelegate = self;
    payPalDriver.appSwitchDelegate = self; // Optional
    
    // Specify the transaction amount here. "2.32" is used in this example.
    BTPayPalRequest *request= [[BTPayPalRequest alloc] initWithAmount:@"2.32"];
    request.currencyCode = @"USD"; // Optional; see BTPayPalRequest.h for other options
    
    [payPalDriver requestOneTimePayment:request completion:^(BTPayPalAccountNonce * _Nullable tokenizedPayPalAccount, NSError * _Nullable error) {
        if (tokenizedPayPalAccount) {
            NSLog(@"Got a nonce: %@", tokenizedPayPalAccount.nonce);
            
            // Access additional information
            NSString *email = tokenizedPayPalAccount.email;
            NSString *firstName = tokenizedPayPalAccount.firstName;
            NSString *lastName = tokenizedPayPalAccount.lastName;
            NSString *phone = tokenizedPayPalAccount.phone;
            
            // See BTPostalAddress.h for details
            BTPostalAddress *billingAddress = tokenizedPayPalAccount.billingAddress;
            BTPostalAddress *shippingAddress = tokenizedPayPalAccount.shippingAddress;
            
            // Send the nonce to server
            [self postNonceToServer:tokenizedPayPalAccount.nonce];
            
        } else if (error) {
            // Handle error here...
        } else {
            // Buyer canceled payment approval
        }
    }];
    
    
}

- (void)postNonceToServer:(NSString *)paymentMethodNonce {
    price = 2.32;
    
    NSURL *paymentURL = [NSURL URLWithString:@"http://orcodevbox.co.uk/max/transaction.php"];
    
    // Let’s construct our POST request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:paymentURL];
    
    // I’m sending the payment nonce as well as the amount but you don’t have to post the amount from your app. You can specify the amount on server side.
    request.HTTPBody = [[NSString stringWithFormat:@"amount=%ld&payment_method_nonce=%@", (long)price,paymentMethodNonce] dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPMethod = @"POST";
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSString *paymentResult = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        // Logging the HTTP request so we can see what is being sent to the server side
        NSLog(@"Request body %@", [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding]);
        
        // Trimming the response for success/failure check so it takes less time to determine the result
        NSString *trimResult =[paymentResult substringToIndex:50];
        
        // Log the transaction result
        NSLog(@"%@",paymentResult);
        
        // I’m going to display the result in an alert controller so I’m using the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Checking the result for the string "Successful" for updating the alert controller
            if ([trimResult containsString:@"Successful"]) {
                NSLog(@"Transaction is successful!");
                resultCheck = @"Transaction successful";
                
            } else {
                NSLog(@"Transaction failed!");
                resultCheck = @"Transaction failed!";
            }
            
            // Create an alert controller to display the transaction result
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:resultCheck
                                                                           message:paymentResult
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
            
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:
                                            UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                
                                            }];
            
            [alert addAction:defaultAction];
            
            [self presentViewController:alert animated:YES completion:nil];
        });
    }] resume];
    
    
}

// Required
- (void)paymentDriver:(id)paymentDriver
    requestsPresentationOfViewController:(UIViewController *)viewController {
    [self presentViewController:viewController animated:YES completion:nil];
}

// Required
- (void)paymentDriver:(id)paymentDriver
    requestsDismissalOfViewController:(UIViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - BTAppSwitchDelegate

// Optional - display and hide loading indicator UI
- (void)appSwitcherWillPerformAppSwitch:(id)appSwitcher {
    [self showLoadingUI];
    
    // You may also want to subscribe to UIApplicationDidBecomeActiveNotification
    // to dismiss the UI when a customer manually switches back to your app since
    // the payment button completion block will not be invoked in that case (e.g.
    // customer switches back via iOS Task Manager)
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hideLoadingUI:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                                 object:nil];
}

- (void)appSwitcherWillProcessPaymentInfo:(id)appSwitcher {
    [self hideLoadingUI:nil];
}

#pragma mark - Private methods

- (void)showLoadingUI {
    
}

- (void)hideLoadingUI:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                    object:nil];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
