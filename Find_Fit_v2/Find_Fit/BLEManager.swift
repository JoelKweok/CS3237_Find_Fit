//
//  ViewController.swift
//  SwiftSensorTag
//
//  Created by Anas Imtiaz on 13/11/2015.
//  Copyright © 2015 Anas Imtiaz. All rights reserved.
//
import Foundation
import CoreBluetooth


class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // BLE
    var centralManager : CBCentralManager!
    @Published var statusLabel = "Loading"
    var sensorTagPeripheral : CBPeripheral!
    @Published var alert = "None"
    
    // Sensor Values
    var allSensorLabels : [String] = []
    var allSensorValues : [Double] = []
    var accelerometerX : Double! = 0
    var accelerometerY : Double!
    var accelerometerZ : Double!
    var gyroscopeX : Double!
    var gyroscopeY : Double!
    var gyroscopeZ : Double!
    var battery_level: Int8!
    var battery_characteristic: CBCharacteristic?
    
    // value  to send
    var global_data: [String: [String:Float]] = [:]
    
    //prediction
    var predict: String!
    var is_running: Bool = false
    
    //timer
    var timer_ble:Timer?
    var timer_characteristic: CBCharacteristic?
    
    override init() {
        super.init()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Initialize central manager on load
        centralManager = CBCentralManager(delegate: self, queue: nil)
        centralManager.delegate = self
        // Initialize all sensor values and labels
        allSensorLabels = SensorTag.getSensorLabels()
        for _ in 0..<allSensorLabels.count {
            allSensorValues.append(0)
        }
    }
    
    /******* CBCentralManagerDelegate *******/
     
     // Check status of BLE hardware
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            // Scan for peripherals if BLE is turned on
            self.statusLabel = "It is on"
        }
        else {
            // Can have different conditions for all states if needed - show generic alert for now
            self.alert = "Bluetooth switched off or not initialized"
        }
    }
    
    func start_scanning(){
        if self.statusLabel == "Sensor Tag Found" {
            self.statusLabel = "Sensor Tag Found"
            
        }
         else if centralManager.state == CBManagerState.poweredOn {
            // Scan for peripherals if BLE is turned on
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            self.statusLabel = "Searching for BLE Devices"
        }
        else {
            // Can have different conditions for all states if needed - show generic alert for now
            self.alert = "Bluetooth switched off or not initialized"
        }
        
    }
    
    func stop_scanning(){
        centralManager.stopScan();
        self.statusLabel = "Stop Scanning"
    }
    
    
    // Check out the discovered peripherals to find Sensor Tag
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if SensorTag.sensorTagFound(advertisementData: advertisementData) == true {
            // Update Status Label
            self.statusLabel = "Sensor Tag Found"
            
            // Stop scanning, set as the peripheral to use and establish connection
            self.centralManager.stopScan()
            self.sensorTagPeripheral = peripheral
            self.sensorTagPeripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil)
        }
        else {
            self.statusLabel = "Sensor Tag NOT Found"
            //showAlertWithText(header: "Warning", message: "SensorTag Not Found")
        }
    }
    
    
    // Discover services of the peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.statusLabel = "Discovering peripheral services"
        peripheral.discoverServices(nil)
    }
    
    
    // If disconnected, start searching again
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if self.statusLabel == "Disconnected"{
            global_data.removeAll()
            self.predict = "NA"
        }
        else{
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    /******* CBCentralPeripheralDelegate *******/
     
     // Check if the service discovered is valid i.e. one of the following:
     // Accelerometer Service
     // Gyroscope Service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        self.statusLabel = "Looking at peripheral services"
        for service in peripheral.services! {
            print(service)
            let thisService = service as CBService
            if SensorTag.validService(service: thisService) {
                // Discover characteristics of all valid services
                peripheral.discoverCharacteristics(nil, for: thisService)
            }
        }
    }
    
    
    // Enable notification and sensor for each characteristic of valid service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        self.statusLabel = "Enabling sensors"
        self.predict = "Predicting..."
        
        for charateristic in service.characteristics! {
            let thisCharacteristic = charateristic as CBCharacteristic
            if SensorTag.validDataCharacteristic(characteristic: thisCharacteristic) {
                // Enable Sensor Notification
                self.sensorTagPeripheral.setNotifyValue(true, for: thisCharacteristic)
                timer_characteristic = thisCharacteristic
            }
            if SensorTag.validConfigCharacteristic(characteristic: thisCharacteristic) {
                // Enable Sensor
                var enableValue = thisCharacteristic.uuid == MovementConfigUUID ? 0x7f : 1
                let enablyBytes = NSData(bytes: &enableValue, length: thisCharacteristic.uuid == MovementConfigUUID ? MemoryLayout<UInt16>.size : MemoryLayout<UInt8>.size)
                self.sensorTagPeripheral.writeValue(enablyBytes as Data, for: thisCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
          //  print(charateristic.uuid)
            if charateristic.uuid == CBUUID(string: "0x2A19") {
                      //  print("Battery characteristic found")
                        peripheral.readValue(for: charateristic)
                        self.sensorTagPeripheral.setNotifyValue(true, for: thisCharacteristic)
                        battery_characteristic = thisCharacteristic
                        print (battery_characteristic?.uuid)
                }
        }
        if(timer_ble == nil){
            timer_ble = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(get_values), userInfo: nil, repeats: true)
        }
        
    }
    
  /*  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if self.battery_characteristic?.uuid == CBUUID(string: "0x2A19") {
            self.battery_level  = dataToSignedBytes8(value: characteristic.value! as NSData,count: 1)
        }
    }   */
    
    @objc func get_values() {
        if(!is_running){
            return
        }
        self.statusLabel = "Connected"
        if(self.timer_characteristic == nil){
            return
        }
        //print(self.timer_characteristic)
        if(self.timer_characteristic?.uuid == nil){
            return
        }
        
        if self.battery_characteristic?.uuid == CBUUID(string: "0x2A19") {
                self.battery_level  = dataToSignedBytes8(value: self.battery_characteristic!.value! as NSData,count: 1)
            }

        if self.timer_characteristic?.uuid  == MovementDataUUID {
            let allValues = SensorTag.getMovementData(value: self.timer_characteristic!.value! as NSData)
            self.accelerometerX = allValues[0]
            self.accelerometerY = allValues[1]
            self.accelerometerZ = allValues[2]
            self.gyroscopeX = allValues[3]
            self.gyroscopeY = allValues[4]
            self.gyroscopeZ = allValues[5]
            self.allSensorValues[0] = self.accelerometerX
            self.allSensorValues[1] = self.accelerometerY
            self.allSensorValues[2] = self.accelerometerZ
            self.allSensorValues[3] = self.gyroscopeX
            self.allSensorValues[4] = self.gyroscopeY
            self.allSensorValues[5] = self.gyroscopeZ
            //let b: String = String(format: "%f", self.allSensorValues[0])
        }
        
        let global_index = global_data.count
        print(global_index)
        print(global_data)
        if(global_index < 33){  //suppose to be 33
            var temp_dict:[String:Float] = [:]
            temp_dict["ax"] = Float(allSensorValues[0])
            temp_dict["ay"] = Float(allSensorValues[1])
            temp_dict["az"] = Float(allSensorValues[2])
            temp_dict["gx"] = Float(allSensorValues[3])
            temp_dict["gy"] = Float(allSensorValues[4])
            temp_dict["gz"] = Float(allSensorValues[5])
            global_data[String(global_index)] = temp_dict
        }
        else if (global_index == 33){ //suppose to be 33
            let url = URL(string: "http://139.99.89.148:11000/api/v1/predict/")
          //  let url = URL(string: "http://139.99.89.148:11000/api/v2/predict/")
            guard let requestUrl = url else { fatalError() }
            var request = URLRequest(url:requestUrl)
      //      let test_data = ["test": "123"]
            request.httpMethod = "POST"
            let postString = json(from: global_data)
            let jsonData = try? JSONSerialization.data(withJSONObject: [postString], options: [])
          //  let jsonData = JSONSerialization.jsonObject(with: postString?, options: []) as? [String:AnyObject]
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let session = URLSession.shared
            let task = session.dataTask(with: request) { (data, response, error)  in
                    
                    // Check for Error
                    if let error = error {
                        print("Error took place \(error)")
                        return
                    }
             
                    // Convert HTTP Response Data to a String
                    if let data = data, let dataString = String(data: data, encoding: .utf8) {
                        do {
                            if let convertedJsonIntoDict = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary {
                                if(convertedJsonIntoDict["success"] == nil){
                                    self.predict = "Error"
                                   // print("line 244")
                                    return
                                }
                            //    print("line 247")
                                print(convertedJsonIntoDict["success"])
                                var predicted_exercise: String
                                predicted_exercise = convertedJsonIntoDict["exercise_type"] as! String as! String
                                self.predict = predicted_exercise
                                print(self.predict)

                                       
                                   }
                        } catch let error as NSError {
                                   print(error.localizedDescription)
                         }
                            
                        //}
                    }
            }
            task.resume()
            global_data.removeAll()
        }
    }

    
    func disconnect_1(_ peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func disconnect() {
        disconnect_1(sensorTagPeripheral)
        self.statusLabel = "Disconnected"
        global_data.removeAll()
        is_running = false
    }
    
    func json(from object:Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else {
            return nil
        }
        return String(data: data, encoding: String.Encoding.utf8)
    }
    
     func dataToSignedBytes8(value : NSData, count: Int) -> Int8 {
            var array = [Int8](repeating: 0, count: count)
            value.getBytes(&array, length:count * MemoryLayout<Int8>.size)
            return array[0]
        }
    
    /******* Helper *******/
     

}
