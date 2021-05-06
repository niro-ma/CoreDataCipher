//
//  EncryptionManager.swift
//  CoreDataCipher
//
//  Created by Niroshan Maheswaran on 06.05.21.
//

import Foundation
import KeychainAccess
import CryptoSwift

/// Private constants of the keys for Keychain.
private enum KeychainKeys {
    
    /// The Keychain field in which the main encryption key will be persisted.
    static let encryptionKey = "encryptionPassword"
    
    /// The Keychain field in which the main initialization vector will be persisted.
    static let initializationVector = "initializationVector"
}

/// Manages encryption related logic and values such as the encryption key
protocol EncryptionManager {
    
    /// Get the current or new encryption key, if none exists. This method can take several seconds to return,
    /// when the key needs to be generated.
    func getEncryptionKey() -> [UInt8]
    
    /// Returns a saved IV or returns a newly created one.
    func getIV() -> [UInt8]
}

/// The encryption manager is responsible for generating or providing the encryption key
/// for the encryption and decryption of the local storage
class EncryptionManagerImpl: EncryptionManager {
    
    // MARK: - Private properties
    
    private let keychain: Keychain
    
    /// The salt that is applied to the key derivation function.
    private let salt: String
    
    /// The byte count of a password, used as an input for PBKDF2.
    private let passwordByteCount: Int
    
    /// The byte count of an AES-256 IV.
    private let ivByteCount: Int
    
    /// Iterations when deriving a key with PBKDF2.
    private let pbkdf2Iterations: Int
    
    /// PBKDF2 Key length.
    private let pbkdf2KeyLength: Int
    
    // MARK: - Public methods
    
    init(
        keychain: Keychain = Keychain(),
        salt: String = "MyF$?.L(]6y7vg9RPy",
        passwordByteCount: Int = 32,
        ivByteCount: Int = 16,
        pbkdf2Iterations: Int = 4096,
        pbkdf2KeyLength: Int = 32
    ) {
        print("Persistence using Keychain with service \"\(keychain.service)\", access group \"\(keychain.accessGroup ?? "none")\"")
    
        self.keychain = keychain
        self.salt = salt
        self.passwordByteCount = passwordByteCount
        self.ivByteCount = ivByteCount
        self.pbkdf2Iterations = pbkdf2Iterations
        self.pbkdf2KeyLength = pbkdf2KeyLength
    }
    
    func getEncryptionKey() -> [UInt8] {
        getBytes(for: KeychainKeys.encryptionKey) {
            let generatedPassword = generateBytes(count: passwordByteCount)
            let key = try derivedKey(password: generatedPassword).get()
            return key
        }
    }
    
    func getIV() -> [UInt8] {
        getBytes(for: KeychainKeys.initializationVector) {
            generateBytes(count: ivByteCount)
        }
    }
}

// MARK: Private methods

/// Private methods and properties
private extension EncryptionManagerImpl {
    
    /// Manages the byte-based access to keychain fields. Checks the provided field key if it contains bytes and if not, uses the
    /// provided generator to create they bytes and persists it in the provided keychain field.
    /// - Parameter keychainField: the keychain field
    /// - Parameter generator: the generator closure to use to create the new bytes to store
    func getBytes(for keychainField: String, generator: () throws -> [UInt8]) -> [UInt8] {
        // Attempt to read from Keychain and fall back to generating the key
        guard let hexString = keychain[keychainField] else {
            print("No bytes found for \(keychainField). Generating new ones and saving it to the keychain.")
            
            do {
                let payload = try generator()
                keychain[keychainField] = payload.toHexString()
                return payload
            } catch {
                fatalError(error.localizedDescription)
            }
        }
        
        return [UInt8].init(hex: hexString)
    }
    
    /// Uses the string as an input and dervies the PBKDF2 derived key with a given
    /// salt.
    ///
    /// - Returns: the key
    func derivedKey(password: [UInt8]) -> Result<[UInt8], Error> {
        Result {
            try PKCS5.PBKDF2(
                password: password,
                salt: salt.bytes,
                iterations: pbkdf2Iterations,
                keyLength: pbkdf2KeyLength
            )
            .calculate()
        }
    }
    
    /// Generates a random key
    private func generateBytes(count: Int) -> [UInt8] {
        (0..<count).map { _ in UInt8.random(in: 0...255) }
    }
}
