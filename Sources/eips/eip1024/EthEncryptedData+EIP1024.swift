//
//  EthEncryptedData+EIP1024.swift
//  MEWwalletKit
//
//  Created by Nail Galiaskarov on 3/11/21.
//  Copyright © 2021 MyEtherWallet Inc. All rights reserved.
//

import Foundation
import MEWwalletTweetNacl
import CryptoSwift

public struct EthEncryptedData: Codable {
  public let nonce: String
  public let ephemPublicKey: String
  public let ciphertext: String
  public private (set) var version = "x25519-xsalsa20-poly1305"
  
  public init(nonce: String, ephemPublicKey: String, ciphertext: String) {
    self.nonce = nonce
    self.ephemPublicKey = ephemPublicKey
    self.ciphertext = ciphertext
  }
    
  /// - Parameters:
  ///   - plaintext: plain text to be necrypted
  ///   - publicKey: public key of recipient
  /// - Returns: EthEncryptedData
  public static func encrypt(plaintext: String, publicKey: String) throws -> EthEncryptedData {
    var nonce = [UInt8](repeating: 0, count: Constants.SecretBox.nonceLength)
    let status = SecRandomCopyBytes(kSecRandomDefault, Constants.SecretBox.nonceLength, &nonce)
    guard status == errSecSuccess else {
      throw TweetNaclError.tweetNacl("Secure random bytes error")
    }
    let ephemKeys = try TweetNacl.keyPair()
    let publicKeyData = Data(hex: publicKey)
      
    let ciphertextData = try TweetNacl.box(message: plaintext, nonce: Data(nonce), theirPublicKey: publicKeyData, mySecretKey: ephemKeys.secretKey)
    guard let ciphertext = String(data: ciphertextData, encoding: .utf8), let nonceString = String(data: Data(nonce), encoding: .utf8), let ephemPublicKeyString = String(data: ephemKeys.publicKey, encoding: .utf8) else {
      throw EthCryptoError.encryptionFailed
    }
    return EthEncryptedData(nonce: nonceString, ephemPublicKey: ephemPublicKeyString, ciphertext: ciphertext)
  }
}

public enum EthCryptoError: Error {
    case decryptionFailed
    case encryptionFailed
}

extension EthEncryptedData {
    public func decrypt(privateKey: String) throws -> String {
        let data = Data(hex: privateKey)
                
        let secretKey = try TweetNacl.keyPair(fromSecretKey: data).secretKey
        
        guard let nonce = Data(base64Encoded: self.nonce),
              let cipherText = Data(base64Encoded: self.ciphertext),
              let ephemPublicKey = Data(base64Encoded: self.ephemPublicKey) else {
          throw EthCryptoError.decryptionFailed
        }
        
        let decrypted = try TweetNacl.open(
            message: cipherText,
            nonce: nonce,
            publicKey: ephemPublicKey,
            secretKey: secretKey
        )
        
        guard let message = String(data: decrypted, encoding: .utf8) else {
            throw EthCryptoError.decryptionFailed
        }
        
        return message
    }
}

extension PrivateKeyEth1 {
  public func eth_publicKey() throws -> String {
    let publicKey = try TweetNacl.keyPair(fromSecretKey: data()).publicKey
    
    return publicKey.toHexString()
  }
}
