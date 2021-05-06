//
//  EncryptionManager.swift
//  CoreDataCipher
//
//  Created by Niroshan Maheswaran on 06.05.21.
//

import Foundation
import CryptoSwift

/*
 Usage:
 - Write the Codable extension for a type to be saved encrypted in CoreData
 - Add the transformer with this type as generic via ValueTransformer.set
 - Set the xcmodel attribute to transformable, the transformer name to "<TYPE>CryptoValueTransformer"
    (or what is returned by our name attribute)
    and the custom class to <TYPE> where <TYPE> is T.self e.g. "String" etc.
 - Done
 
 Example for String:
 - add CryptoValueTransformer<String>(cipher: ...) in DataController
 - set StringCryptoValueTransformer and String in xcdatamodel
 - Done
 
 Since T must conform to Codable, we could store any struct or object that
 is serializable with Codable encrypted in CoreData.
*/

/// Protocol to make sure an object can return its value transformer name.
protocol ValueTransformerNamed {
    /// Name of value transformer
    var name: NSValueTransformerName { get }
}

/// ValueTransformer that takes Codable as generic and a cipher as an input and will
/// en- and decrypt CoreData transformable properties while read or written.
class CryptoValueTransformer<T: Codable>: ValueTransformer {
    
    // MARK: - Public  properties
    
    // The cipher to be used to en/decrypt
    let cipher: Cipher
    
    /*
     Since we use the Codable protocol as a proxy for everything we want to en/decrypt,
     we can just use the JSONEn-/Decoder to get transformable data. Since we can expect
     single values such as strings as an input, we will always wrap the value into an array,
     so that the encoding will never fail during validation. This will result in a bit of
     overhead and if that is a concern we could implement a DataEncoder and DataDecoder instead.
    */
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    
    // MARK: - Public methods
    
    /// Initialize transformer with a cipher of any kind.
    ///
    /// - Parameter cipher: the cipher to use for en/decryption.
    init(cipher: Cipher) {
        self.cipher = cipher
        super.init()
    }
    
    /// Encrypts a T into data value.
    ///
    /// - Parameter value: the string
    /// - Returns: encrypted data
    override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value as? T else { return nil }
        do {
            // wrapping the value in an array will dodge JSON validation issues
            let data = try encoder.encode([value])
            let encrypted = try data.bytes.encrypt(cipher: cipher)
            
            // return encrypted raw data
            return Data(encrypted)
        } catch {
            print(error)
            return nil
        }
    }
    
    /// Decrypts a data value back to T representation.
    /// Data -> T
    /// - Parameter value: the data value
    /// - Returns: string value
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do {
            // decrypt raw data from database
            let decrypted = try data.bytes.decrypt(cipher: cipher)
            
            // return decoded type
            return try decoder.decode([T].self, from: Data(decrypted)).first
        } catch {
            print(error)
            return nil
        }
    }
    
    /// Going both ways: read and write.
    ///
    /// - Returns: bool
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
}

// MARK: Extension for name

extension CryptoValueTransformer: ValueTransformerNamed {
    
    var name: NSValueTransformerName {
        return NSValueTransformerName(rawValue: "\(String(describing: T.self))CryptoValueTransformer")
    }
}
