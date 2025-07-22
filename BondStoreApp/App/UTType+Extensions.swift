//
//  UTType+Extensions.swift
//  BondStoreApp
//
//  Created by Valentyn on 22.07.25.
//

import UniformTypeIdentifiers

extension UTType {
    // This defines a type that is specifically linked to the ".store" file extension
    // and tells the system it conforms to a generic data type.
    static var database: UTType {
        UTType(filenameExtension: "store", conformingTo: .data) ?? .data
    }
}
