//
//  ViewController.swift
//  SwiftSensorTag
//
//  Created by Anas Imtiaz on 13/11/2015.
//  Copyright © 2015 Anas Imtiaz. All rights reserved.
//
import UIKit
import CoreBluetooth


class ViewController: UIViewController {
    var bleManager = BLEManager()
    
    // Title labels
    var titleLabel : UILabel!
    var statusLabel : UILabel!
    
    
    // BLE
    var centralManager : CBCentralManager!
    var sensorTagPeripheral : CBPeripheral!
    
    
    // Sensor Values
    var allSensorLabels : [String] = []
    var allSensorValues : [Double] = []
    var accelerometerX : Double!
    var accelerometerY : Double!
    var accelerometerZ : Double!
    var gyroscopeX : Double!
    var gyroscopeY : Double!
    var gyroscopeZ : Double!
    
    // value  to send
    var global_data: [String: [String:Double]] = [:]
    
    //prediction
    var predict: String!
    
    //storyboard
    @IBOutlet weak var Battery: UILabel!
    @IBOutlet weak var timer_value: UILabel!
    @IBOutlet weak var prediction_value: UILabel!
    
    var timer:Timer?
    var time_value: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        // Set up title label
        titleLabel = UILabel()
        titleLabel.text = "Find_Fit"
        titleLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 20)
        titleLabel.sizeToFit()
        titleLabel.center = CGPoint(x: self.view.frame.midX, y: self.titleLabel.bounds.midY+28)
        self.view.addSubview(titleLabel)
        
        // Set up status label
        statusLabel = UILabel()
        statusLabel.textAlignment = NSTextAlignment.center
        statusLabel.text = "None"
        statusLabel.font = UIFont(name: "HelveticaNeue-Light", size: 12)
        statusLabel.sizeToFit()
        //statusLabel.center = CGPoint(x: self.view.frame.midX, y: (titleLabel.frame.maxY + statusLabel.bounds.height/2) )
        statusLabel.frame = CGRect(x: self.view.frame.origin.x, y: self.titleLabel.frame.maxY, width: self.view.frame.width, height: self.statusLabel.bounds.height)
        self.view.addSubview(statusLabel)
        
        // Initialize all sensor values and labels
        allSensorLabels = SensorTag.getSensorLabels()
        for _ in 0..<allSensorLabels.count {
            allSensorValues.append(0)
        }
        
    }
    
    @IBAction func begin(_ sender: Any) {
        bleManager.start_scanning()
        Battery.text = "Reading"
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(onTimerFires), userInfo: nil, repeats: true)
        print(bleManager.statusLabel)
    }

    
    @objc func onTimerFires()
    {
        timer_value.text = String(time_value)
        if bleManager.statusLabel == "Connected"{
            time_value = time_value + 1
            prediction_value.text = bleManager.predict
        }
        statusLabel.text = bleManager.statusLabel
        bleManager.is_running = true
        if(bleManager.battery_level != nil) {
            Battery.text = String(bleManager.battery_level) + "%"
           // print(Battery.text)
        }
        else{
            Battery.text = "error"
        }
        
    }

    @IBAction func stop(_ sender: Any) {
        timer?.invalidate()
        timer_value.text = "Not Started"
        time_value = 0
        prediction_value.text = "NA"
        bleManager.disconnect()
        statusLabel.text = bleManager.statusLabel
        bleManager.is_running = false
        Battery.text = "Battery"
        
    }
}
