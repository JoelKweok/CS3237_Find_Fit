//
//  SensorTag.swift
//  SwiftSensorTag
//
//  Created by Anas Imtiaz on 13/11/2015.
//  Copyright © 2015 Anas Imtiaz. All rights reserved.
//
import Foundation
import CoreBluetooth


let deviceName = "SensorTag"

// Service UUIDs
let MovementServiceUUID      = CBUUID(string: "F000AA80-0451-4000-B000-000000000000")

// Characteristic UUIDs
let MovementDataUUID        = CBUUID(string: "F000AA81-0451-4000-B000-000000000000")
let MovementConfigUUID      = CBUUID(string: "F000AA82-0451-4000-B000-000000000000")

let Battery_Service_UUID = CBUUID(string: "0000180F-0000-1000-8000-00805f9b34fb")

let Battery_Level_UUID = CBUUID(string: "00002a19-0000-1000-8000-00805f9b34fb")


class SensorTag {
    
    // Check name of device from advertisement data
    class func sensorTagFound (advertisementData: [String : Any]!) -> Bool {
        if (advertisementData["kCBAdvDataLocalName"]) != nil {
            let advData = advertisementData["kCBAdvDataLocalName"] as! String
            return(advData.range(of: deviceName) != nil)
        }
        return false
    }
    
    
    // Check if the service has a valid UUID
    class func validService (service : CBService) -> Bool {
        if service.uuid == MovementServiceUUID || service.uuid == Battery_Service_UUID {
                return true
        }
        else {
            return false
        }
    }
    
    
    // Check if the characteristic has a valid data UUID
    class func validDataCharacteristic (characteristic : CBCharacteristic) -> Bool {
        if  characteristic.uuid == MovementDataUUID || characteristic.uuid == Battery_Level_UUID {
                return true
        }
        else {
            return false
        }
    }
    
    
    // Check if the characteristic has a valid config UUID
    class func validConfigCharacteristic (characteristic : CBCharacteristic) -> Bool {
        if characteristic.uuid == MovementConfigUUID {
                return true
        }
        else {
            return false
        }
    }
    
    
    // Get labels of all sensors
    class func getSensorLabels () -> [String] {
        let sensorLabels : [String] = [
            "Accelerometer X",
            "Accelerometer Y",
            "Accelerometer Z",
            "Gyroscope X",
            "Gyroscope Y",
            "Gyroscope Z"
        ]
        return sensorLabels
    }
    
    
    
    // Process the values from sensor
    
    
    // Convert NSData to array of bytes
    class func dataToSignedBytes16(value : NSData, count: Int) -> [Int16] {
        var array = [Int16](repeating: 0, count: count)
        value.getBytes(&array, length:count * MemoryLayout<Int16>.size)
        return array
    }
    
        
    // Get Accelerometer values
    class func getMovementData(value: NSData) -> [Double] {
        let dataFromSensor = dataToSignedBytes16(value: value, count: 9)
        let range = 2.0
        let ax = Double(dataFromSensor[0]) * range / 32768.0
        let ay = Double(dataFromSensor[1]) * range / 32768.0
        let az = Double(dataFromSensor[2]) * range / 32768.0
        let gx = Double(dataFromSensor[3]) * 500.0 / 65536.0
        let gy = Double(dataFromSensor[4]) * 500.0 / 65536.0
        let gz = Double(dataFromSensor[5]) * 500.0 / 65536.0
        return [ax, ay, az, gx, gy, gz]
    }
    
}
