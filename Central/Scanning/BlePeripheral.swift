//
//  Peripheral.swift
//  FlowControl
//
//  Created by Adonis Gaitatzis on 12/2/16.
//  Copyright © 2016 Adonis Gaitatzis. All rights reserved.
//

import UIKit
import CoreBluetooth

/**
 BlePeripheral Handles communication with a Bluetooth Low Energy Peripheral
 */
class BlePeripheral: NSObject, CBPeripheralDelegate {
    
    // MARK: Peripheral properties
    
    // the size of the characteristic
    let characteristicLength = 20
    
    // MARK: Flow control
    
    // Flow control response
    let flowControlMessage = "ready"
    
    // outbound value to be sent to the Characteristic
    var outboundByteArray:[UInt8]!
    
    // packet offset in multi-packet value
    var packetOffset = 0
    
    
    
    // MARK: connected device
    
    // GATT profile tree
    var gattProfile = [CBService]()
    
    // connected Peripheral
    var peripheral:CBPeripheral!
    
    // The Adverstised name of the Perihperal
    var advertisedName:String!
    
    // The RSSI of the Perpheral
    var rssi:NSNumber!

    // delegate
    var delegate:BlePeripheralDelegate?
    
    
    
    /**
     Initialize BlePeripheral with a corresponding Peripheral
     
     - Parameters:
     - delegate: The BlePeripheralDelegate
     - peripheral: The discovered Peripheral
     */
    init(delegate: BlePeripheralDelegate?, peripheral: CBPeripheral) {
        super.init()
        self.peripheral = peripheral
        self.peripheral.delegate = self
        self.delegate = delegate
    }

    
    /**
     Notify the BlePeripheral that the peripheral has been connected
     
     - Parameters:
        - peripheral: The discovered Peripheral
     */
    func connected(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.peripheral.delegate = self
        
        // check for services and the RSSI
        self.peripheral.readRSSI()
        self.peripheral.discoverServices(nil)
    }
    
    /**
     Get a broadcast name from an advertisementData packet.  This may be different than the actual broadcast name
     */
    static func getNameFromAdvertisementData(advertisementData: [String : Any]) -> String? {
        // grab thekCBAdvDataLocalName from the advertisementData to see if there's an alternate broadcast name
        if advertisementData["kCBAdvDataLocalName"] != nil {
            return (advertisementData["kCBAdvDataLocalName"] as! String)
        }
        return nil
    }
    
    /**
     Determine if this peripheral is connectable from it's advertisementData packet.
     */
    static func isConnectable(advertisementData: [String: Any]) -> Bool {
        let isConnectable = advertisementData["kCBAdvDataIsConnectable"] as! Bool
        return isConnectable
    }

    
    
    /**
     Read from a Characteristic
     */
    func readValue(from characteristic: CBCharacteristic) {
        self.peripheral.readValue(for: characteristic)
    }

    
    
    
    
    /**
     Write a text value to the BlePeripheral
     
     - Parameters:
     - value: the value to write to the connected Characteristic
     */
    func writeValue(value: String, to characteristic: CBCharacteristic) {
        // get the characteristic length
        let writeableValue = value + "\0"
        packetOffset = 0
        
        // get the data for the current offset
        outboundByteArray = Array(writeableValue.utf8)
        
        writePartialValue(value: outboundByteArray, offset: packetOffset, to: characteristic)
    }
    
    
    /**
     Write a partial value to the BlePeripheral
     
     - Parameters:
     - value: the full value to write to the connected Characteristic
     - offset: the packet offset
     
     */
    func writePartialValue(value: [UInt8], offset: Int, to characteristic: CBCharacteristic) {
        // don't go past the total value size
        var end =  offset + characteristicLength
        
        if end > outboundByteArray.count {
            end = outboundByteArray.count
        }
        
        
        let transmissableValue = Data(Array(outboundByteArray[offset..<end]))
        
        print("writing partial value:  \(offset)-\(end)")
        print(transmissableValue)
        
        var writeType = CBCharacteristicWriteType.withResponse
        if BlePeripheral.isCharacteristic(isWriteableWithoutResponse: characteristic) {
            writeType = CBCharacteristicWriteType.withoutResponse
        }
        
        peripheral.writeValue(transmissableValue, for: characteristic, type: writeType)
        print("write request sent")
    }
    
    
    /**
     Subscribe to the connected characteristic.
     
     When change is successful, delegate.subscriptionStateChanged() called
     */
    func subscribeTo(characteristic: CBCharacteristic) {
        self.peripheral.setNotifyValue(true, for: characteristic)
    }
    
    /**
     Unsubscribe from the connected characteristic.
     
     When change is successful, delegate.subscriptionStateChanged() called
     */
    func unsubscribeFrom(characteristic: CBCharacteristic) {
        self.peripheral.setNotifyValue(false, for: characteristic)
    }
    
    
    /**
     Check if Characteristic is readable
     
     - Parameters:
     - characteristic: The Characteristic to test
     
     - returns: True if characteristic is readable
     */
    static func isCharacteristic(isReadable characteristic: CBCharacteristic) -> Bool {
        if (characteristic.properties.rawValue & CBCharacteristicProperties.read.rawValue) != 0 {
            return true
        }
        return false
    }
    
    
    /**
     Check if Characteristic is writeable
     
     - Parameters:
     - characteristic: The Characteristic to test
     
     - returns: True if characteristic is writeable
     */
    static func isCharacteristic(isWriteable characteristic: CBCharacteristic) -> Bool {
        if (characteristic.properties.rawValue & CBCharacteristicProperties.write.rawValue) != 0 ||
            (characteristic.properties.rawValue & CBCharacteristicProperties.writeWithoutResponse.rawValue) != 0 {
            return true
        }
        return false
    }
    
    
    /**
     Check if Characteristic is writeable with response
     
     - Parameters:
     - characteristic: The Characteristic to test
     
     - returns: True if characteristic is writeable with response
     */
    static func isCharacteristic(isWriteableWithResponse characteristic: CBCharacteristic) -> Bool {
        if (characteristic.properties.rawValue & CBCharacteristicProperties.write.rawValue) != 0 {
            return true
        }
        return false
    }
    
    
    /**
     Check if Characteristic is writeable without response
     
     - Parameters:
     - characteristic: The Characteristic to test
     
     - returns: True if characteristic is writeable without response
     */
    static func isCharacteristic(isWriteableWithoutResponse characteristic: CBCharacteristic) -> Bool {
        if (characteristic.properties.rawValue & CBCharacteristicProperties.writeWithoutResponse.rawValue) != 0 {
            return true
        }
        return false
    }
    
    
    /**
     Check if Characteristic is notifiable
     
     - Parameters:
     - characteristic: The Characteristic to test
     
     - returns: True if characteristic is notifiable
     */
    static func isCharacteristic(isNotifiable characteristic: CBCharacteristic) -> Bool {
        if (characteristic.properties.rawValue & CBCharacteristicProperties.notify.rawValue) != 0 {
            return true
        }
        return false
    }
    
    
    // MARK: CBPeripheralDelegate
    
    
    /**
     Characteristic has been subscribed to or unsubscribed from
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("Notification state updated for: \(characteristic.uuid.uuidString)")
        print("New state: \(characteristic.isNotifying)")
        
    
        
        delegate?.blePeripheral?(subscriptionStateChanged: characteristic.isNotifying, characteristic: characteristic, blePeripheral: self)
        
        
        if let errorValue = error {
            print("error subscribing to notification: ")
            print(errorValue.localizedDescription)
        }
    }
    
    
    /**
     Value was written to the Characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        print("data written")
    }
    
    
    /**
     Value downloaded from Characteristic on connected Peripheral
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("characteristic updated")
        if let value = characteristic.value {
            
            print(value.debugDescription)
            print(value.description)
            
            
            // Note: if we need to work with byte arrays instead of Strings, we can do this
            // let byteArray = [UInt8](value)
            // or this:
            // let byteArray:[UInt8] = Array(outboundValue.withCString)
            
            if let stringValue = String(data: value, encoding: .ascii) {
                
                print(stringValue)
                
                // received response from Peripheral
                delegate?.blePeripheral?(characteristicRead: stringValue, characteristic: characteristic, blePeripheral: self)
                

                if stringValue == flowControlMessage {
                    packetOffset += characteristicLength
                    if packetOffset < outboundByteArray.count {
                        writePartialValue(value: outboundByteArray, offset: packetOffset, to: characteristic)
                        
                    } else {
                        print("value write complete")
                        // done writing message
                        delegate?.blePeripheral?(valueWritten: characteristic, blePeripheral: self)
                        
                    }
                }
            }
        }
    }
    
    
    /**
     Servicess were discovered on the connected Peripheral
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("services discovered")
        // clear GATT profile - start with fresh services listing
        gattProfile.removeAll()
        
        if error != nil {
            print("Discover service Error: \(error)")
        } else {
            print("Discovered Service")
            for service in peripheral.services!{
                self.peripheral.discoverCharacteristics(nil, for: service)
            }
            print(peripheral.services!)
        }
        
    }
    
    
    /**
     Characteristics were discovered for a Service on the connected Peripheral
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("characteristics discovered")
        // grab the service
        let serviceIdentifier = service.uuid.uuidString
        
        print("service: \(serviceIdentifier)")
        
        gattProfile.append(service)
        
        if let characteristics = service.characteristics {
            
            print("characteristics found: \(characteristics.count)")
            for characteristic in characteristics {
                print("-> \(characteristic.uuid.uuidString)")
                
            }
            
            delegate?.blePerihperal?(discoveredCharacteristics: characteristics, forService: service,blePeripheral: self)
        }
        
    }
    
    
    /**
     RSSI read from peripheral.
     */
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        print("RSSI: \(RSSI.stringValue)")
        rssi = RSSI
        delegate?.blePeripheral?(readRssi: rssi, blePeripheral: self)
        
    }
    
    
}
