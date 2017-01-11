//
//  ViewController.swift
//  ServiceManager
//
//  Created by utsav.patel on 10/01/17.
//  Copyright © 2017 utsav.patel. All rights reserved.
//

import UIKit
import ServiceApi

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        methodSegmentAction(methodSegment)
    }
    
    @IBOutlet weak var HeaderSwitch: UISwitch!
    @IBOutlet weak var ParameterSwitch: UISwitch!
    @IBOutlet weak var FileSwitch: UISwitch!
    
    @IBOutlet weak var methodSegment: UISegmentedControl!
    
    
    var service : ServiceApi?
    
    @IBAction func methodSegmentAction(_ segment: UISegmentedControl) {
        if segment.selectedSegmentIndex == 0 || segment.selectedSegmentIndex == 2 {  // post
            FileSwitch.isEnabled  = true
        }else{
            FileSwitch.isEnabled  = false
        }
    }
    
    @IBAction func sendRequestAction(_ sender: Any) {
        
        if methodSegment.selectedSegmentIndex == 0 {  // post
            service = NodeTest.callService(header: HeaderSwitch.isOn, file: FileSwitch.isOn, param: ParameterSwitch.isOn, serviceType: .POST)
        }else if methodSegment.selectedSegmentIndex == 1 {  // GET
            service = NodeTest.callService(header: HeaderSwitch.isOn, file: FileSwitch.isOn, param: ParameterSwitch.isOn, serviceType: .GET)
        }else if methodSegment.selectedSegmentIndex == 2 {  // put
            service = NodeTest.callService(header: HeaderSwitch.isOn, file: FileSwitch.isOn, param: ParameterSwitch.isOn, serviceType: .PUT)
        }else{  // delete
            service = NodeTest.callService(header: HeaderSwitch.isOn, file: FileSwitch.isOn, param: ParameterSwitch.isOn, serviceType: .DELETE)
        }
    }
    
    @IBAction func cancelRequestAction(_ sender: Any) {
        
        if service?.isCancelable == true {
            service?.cancel()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
