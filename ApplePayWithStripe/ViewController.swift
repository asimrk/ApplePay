//
//  ViewController.swift
//  ApplePayWithStripe
//
//  Created by HigherVisibility on 13/12/2016.
//  Copyright © 2016 ahmedHigherVisibility. All rights reserved.
//

import UIKit
import Stripe

enum STPBackendChargeResult {
    case Success, Failure
}

typealias STPTokenSubmissionHandler = (STPBackendChargeResult?, NSError?) -> Void


class ViewController: UIViewController, PKPaymentAuthorizationViewControllerDelegate {
    
    // Replace these values with your application's keys
    
    // Find this at https://dashboard.stripe.com/account/apikeys
    let stripePublishableKey = "pk_test_roz5EbzmnlrWRPYKQOSx9id3"
    
    // To set this up, see https://github.com/stripe/example-ios-backend
    let backendChargeURLString = "https://stripepractice.herokuapp.com/"
    
    // To set this up, see https://stripe.com/docs/mobile/apple-pay
    let appleMerchantId = "merchant.com.HigherVisibility.Stripe"
    
    let shirtPrice : UInt = 1000 // this is in cents
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let button = PKPaymentButton(type: .Buy, style: .Black)
        button.addTarget(self, action: #selector(ViewController.beginPayment), forControlEvents: .TouchUpInside)
        let bw = button.frame.size.width
        let bh = button.frame.size.height
        let vw = view.frame.size.width
        let vh = view.frame.size.height
        button.frame = CGRect(origin: CGPointMake(vw/2 - bw/2, vh/2 - bh/2), size: button.frame.size)
        view.addSubview(button)
        
    }
    
    func beginPayment(sender: AnyObject) {
        if (stripePublishableKey == "") {
            let alert = UIAlertController(
                title: "You need to set your Stripe publishable key.",
                message: "You can find your publishable key at https://dashboard.stripe.com/account/apikeys .",
                preferredStyle: UIAlertControllerStyle.Alert
            )
            let action = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
            alert.addAction(action)
            presentViewController(alert, animated: true, completion: nil)
            return
        }
        if (appleMerchantId != "") {
            if let paymentRequest = Stripe.paymentRequestWithMerchantIdentifier(appleMerchantId) {
                if Stripe.canSubmitPaymentRequest(paymentRequest) {
                    paymentRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: "Cool shirt", amount: NSDecimalNumber(string: "10.00")), PKPaymentSummaryItem(label: "Stripe shirt shop", amount: NSDecimalNumber(string: "10.00"))]
                    let paymentAuthVC = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest)
                    paymentAuthVC.delegate = self
                    presentViewController(paymentAuthVC, animated: true, completion: nil)
                    return
                }
            }
        } else {
            print("You should set an appleMerchantId.")
        }
    }
    
    func paymentAuthorizationViewController(controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: ((PKPaymentAuthorizationStatus) -> Void)) {
        let apiClient = STPAPIClient(publishableKey: stripePublishableKey)
        apiClient.createTokenWithPayment(payment, completion: { (token, error) -> Void in
            if error == nil {
                if let token = token {
                    self.createBackendChargeWithToken(token, completion: { (result, error) -> Void in
                        if result == STPBackendChargeResult.Success {
                            completion(PKPaymentAuthorizationStatus.Success)
                        }
                        else {
                            completion(PKPaymentAuthorizationStatus.Failure)
                        }
                    })
                }
            }
            else {
                completion(PKPaymentAuthorizationStatus.Failure)
            }
        })
    }
    
    func paymentAuthorizationViewControllerDidFinish(controller: PKPaymentAuthorizationViewController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func createBackendChargeWithToken(token: STPToken, completion: STPTokenSubmissionHandler) {
        if backendChargeURLString != "" {
            if let url = NSURL(string: backendChargeURLString  + "/charge") {
                
                let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
                let request = NSMutableURLRequest(URL: url)
                request.HTTPMethod = "POST"
                let postBody = "stripeToken=\(token.tokenId)&amount=\(shirtPrice)"
                let postData = postBody.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
                session.uploadTaskWithRequest(request, fromData: postData, completionHandler: { data, response, error in
                    let successfulResponse = (response as? NSHTTPURLResponse)?.statusCode == 200
                    if successfulResponse && error == nil {
                        completion(.Success, nil)
                    } else {
                        if error != nil {
                            completion(.Failure, error)
                        } else {
                            completion(.Failure, NSError(domain: StripeDomain, code: 50, userInfo: [NSLocalizedDescriptionKey: "There was an error communicating with your payment backend."]))
                        }
                        
                    }
                }).resume()
                
                return
            }
        }
        completion(STPBackendChargeResult.Failure, NSError(domain: StripeDomain, code: 50, userInfo: [NSLocalizedDescriptionKey: "You created a token! Its value is \(token.tokenId). Now configure your backend to accept this token and complete a charge."]))
    }
}



